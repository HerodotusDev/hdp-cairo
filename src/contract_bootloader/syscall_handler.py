from typing import (
    Dict,
    Iterable,
)
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from contract_bootloader.syscall_handler_base import SyscallHandlerBase
from starkware.cairo.common.dict import DictManager
from starkware.cairo.common.structs import CairoStructProxy
from starkware.starknet.business_logic.execution.objects import CallResult
from contract_bootloader.memorizer.evm.memorizer import EvmStateId, EvmMemorizer
from contract_bootloader.memorizer.evm.header import (
    EvmStateFunctionId as EvmHeaderFunctionId,
    MemorizerKey as EvmHeaderKey,
)
from contract_bootloader.memorizer.evm.account import (
    EvmStateFunctionId as EvmAccountFunctionId,
    MemorizerKey as EvmAccountKey,
)
from contract_bootloader.memorizer.evm.storage import (
    EvmStateFunctionId as EvmStorageFunctionId,
    MemorizerKey as EvmStorageKey,
)
from contract_bootloader.memorizer.evm.block_tx import (
    EvmStateFunctionId as EvmBlockTxFunctionId,
    MemorizerKey as EvmBlockTxKey,
)
from contract_bootloader.memorizer.evm.block_receipt import (
    EvmStateFunctionId as EvmBlockReceiptFunctionId,
    MemorizerKey as EvmBlockReceiptKey,
)
from contract_bootloader.syscall_memorizer_handler.evm.account_handler import (
    EvmAccountHandler,
)
from contract_bootloader.syscall_memorizer_handler.evm.header_handler import (
    EvmHeaderHandler,
)
from contract_bootloader.syscall_memorizer_handler.evm.storage_handler import (
    EvmStorageHandler,
)
from contract_bootloader.syscall_memorizer_handler.evm.block_tx_handler import (
    EvmBlockTxHandler,
)
from contract_bootloader.syscall_memorizer_handler.evm.block_receipt_handler import (
    EvmBlockReceiptHandler,
)
from contract_bootloader.memorizer.starknet.memorizer import (
    StarknetStateId,
    StarknetMemorizer,
)
from contract_bootloader.memorizer.starknet.header import (
    MemorizerKey as StarknetHeaderKey,
    StarknetStateFunctionId as StarknetHeaderFunctionId,
)
from contract_bootloader.memorizer.starknet.storage import (
    MemorizerKey as StarknetStorageKey,
    StarknetStateFunctionId as StarknetStorageFunctionId,
)
from contract_bootloader.syscall_memorizer_handler.starknet.header_handler import (
    StarknetHeaderHandler,
)
from contract_bootloader.syscall_memorizer_handler.starknet.storage_handler import (
    StarknetStorageHandler,
)

from enum import Enum


class ChainType(Enum):
    EVM = "evm"
    STARKNET = "starknet"


def get_chain_type(chain_id: int) -> ChainType:
    if chain_id == 393402133025997798000961 or chain_id == 23448594291968334:
        return ChainType.STARKNET
    return ChainType.EVM


class SyscallHandler(SyscallHandlerBase):
    """
    A handler for system calls; used by the BusinessLogic entry point execution.
    """

    def __init__(
        self,
        dict_manager: DictManager,
        segments: MemorySegmentManager,
    ):
        super().__init__(segments=segments, initial_syscall_ptr=None)
        self.syscall_counter: Dict[str, int] = {}
        self.dict_manager = dict_manager

    def set_syscall_ptr(self, syscall_ptr: RelocatableValue):
        assert self._syscall_ptr is None, "syscall_ptr is already set."
        self._syscall_ptr = syscall_ptr

    def allocate_segment(self, data: Iterable[MaybeRelocatable]) -> RelocatableValue:
        segment_start = self.segments.add()
        self.segments.write_arg(ptr=segment_start, arg=data)
        return segment_start

    def _allocate_segment_for_retdata(self, retdata: Iterable[int]) -> RelocatableValue:
        return self.allocate_segment(data=retdata)

    def _call_contract_helper(
        self, request: CairoStructProxy, syscall_name: str
    ) -> CallResult:
        calldata = self._get_felt_range(
            start_addr=request.calldata_start, end_addr=request.calldata_end
        )
        chain_id = calldata[2]
        chain_type = get_chain_type(chain_id)

        if chain_type == ChainType.EVM:
            return self._handle_evm_call(request, calldata)
        else:
            return self._handle_starknet_call(request, calldata)

    def _handle_evm_call(self, request: CairoStructProxy, calldata: list) -> CallResult:
        retdata = []
        memorizerId = EvmStateId.from_int(request.contract_address)
        handlers = {
            EvmStateId.Header: (EvmHeaderHandler, EvmHeaderKey, EvmHeaderFunctionId),
            EvmStateId.Account: (
                EvmAccountHandler,
                EvmAccountKey,
                EvmAccountFunctionId,
            ),
            EvmStateId.Storage: (
                EvmStorageHandler,
                EvmStorageKey,
                EvmStorageFunctionId,
            ),
            EvmStateId.BlockTx: (
                EvmBlockTxHandler,
                EvmBlockTxKey,
                EvmBlockTxFunctionId,
            ),
            EvmStateId.BlockReceipt: (
                EvmBlockReceiptHandler,
                EvmBlockReceiptKey,
                EvmBlockReceiptFunctionId,
            ),
        }

        if memorizerId not in handlers:
            raise ValueError(f"EvmStateId {memorizerId} not matched")

        HandlerClass, KeyClass, FunctionIdClass = handlers[memorizerId]
        total_size = EvmMemorizer.size() + KeyClass.size()

        if len(calldata) != total_size:
            raise ValueError(
                f"Memorizer read must be initialized with a list of {total_size} integers"
            )

        memorizer = EvmMemorizer(
            dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
            dict_manager=self.dict_manager,
        )

        idx = EvmMemorizer.size()
        key = KeyClass.from_int(calldata[idx : idx + KeyClass.size()])
        function_id = FunctionIdClass.from_int(request.selector)

        handler = HandlerClass(
            segments=self.segments,
            memorizer=memorizer,
        )
        retdata = handler.handle(function_id=function_id, key=key)

        return CallResult(gas_consumed=0, failure_flag=0, retdata=list(retdata))

    def _handle_starknet_call(
        self, request: CairoStructProxy, calldata: list
    ) -> CallResult:
        retdata = []
        memorizerId = StarknetStateId.from_int(request.contract_address)
        handlers = {
            StarknetStateId.Header: (
                StarknetHeaderHandler,
                StarknetHeaderKey,
                StarknetHeaderFunctionId,
            ),
            StarknetStateId.Storage: (
                StarknetStorageHandler,
                StarknetStorageKey,
                StarknetStorageFunctionId,
            ),
        }

        if memorizerId not in handlers:
            raise ValueError(f"StarknetStateId {memorizerId} not matched")

        HandlerClass, KeyClass, FunctionIdClass = handlers[memorizerId]
        total_size = StarknetMemorizer.size() + KeyClass.size()

        if len(calldata) != total_size:
            raise ValueError(
                f"Memorizer read must be initialized with a list of {total_size} integers"
            )

        memorizer = StarknetMemorizer(
            dict_raw_ptrs=calldata[0 : StarknetMemorizer.size()],
            dict_manager=self.dict_manager,
        )

        idx = StarknetMemorizer.size()
        key = KeyClass.from_int(calldata[idx : idx + KeyClass.size()])
        function_id = FunctionIdClass.from_int(request.selector)

        handler = HandlerClass(
            segments=self.segments,
            memorizer=memorizer,
        )
        retdata = handler.handle(function_id=function_id, key=key)
        retdata = [retdata]  # since we return a single felt for now

        return CallResult(gas_consumed=0, failure_flag=0, retdata=retdata)
