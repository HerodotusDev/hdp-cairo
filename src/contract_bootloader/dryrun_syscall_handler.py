import os
from typing import (
    Dict,
    Iterable,
)
from src.contract_bootloader.dryrun_syscall_memorizer_handler.starknet.header_handler import (
    DryRunStarknetHeaderHandler,
)
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from contract_bootloader.syscall_handler_base import SyscallHandlerBase
from starkware.cairo.common.dict import DictManager
from starkware.cairo.common.structs import CairoStructProxy
from starkware.starknet.business_logic.execution.objects import CallResult
from contract_bootloader.memorizer.evm.memorizer import EvmStateId, EvmMemorizer
from contract_bootloader.memorizer.starknet.memorizer import (
    StarknetStateId,
    StarknetMemorizer,
)
from contract_bootloader.memorizer.evm.account import (
    EvmStateFunctionId as EvmAccountFunctionId,
    MemorizerKey as EvmAccountKey,
)
from contract_bootloader.memorizer.evm.header import (
    EvmStateFunctionId as EvmHeaderFunctionId,
    MemorizerKey as EvmHeaderKey,
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
from contract_bootloader.dryrun_syscall_memorizer_handler.evm.header_handler import (
    DryRunEvmHeaderHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.evm.account_handler import (
    DryRunEvmAccountHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.evm.storage_handler import (
    DryRunEvmStorageHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.evm.block_tx_handler import (
    DryRunEvmBlockTxHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.evm.block_receipt_handler import (
    DryRunEvmBlockReceiptHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.starknet.header_handler import (
    DryRunStarknetHeaderHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.starknet.storage_handler import (
    DryRunStarknetStorageHandler,
)
from contract_bootloader.memorizer.starknet.header import (
    MemorizerKey as StarknetHeaderKey,
    StarknetStateFunctionId as StarknetHeaderFunctionId,
)
from contract_bootloader.memorizer.starknet.storage import (
    MemorizerKey as StarknetStorageKey,
    StarknetStateFunctionId as StarknetStorageFunctionId,
)
from enum import Enum

# Load environment variables from a .env file if present
from dotenv import load_dotenv
from tools.py.providers.evm.provider import EvmKeyProvider
from tools.py.providers.starknet.provider import StarknetKeyProvider

load_dotenv()

RPC_URL = os.getenv("RPC_URL")
PROVIDER_URL_STARKNET = os.getenv("PROVIDER_URL_STARKNET")
FEEDER_URL = os.getenv(
    "STARKNET_FEEDER_URL", "https://alpha-sepolia.starknet.io/feeder_gateway/"
)

if not RPC_URL:
    raise ValueError(
        "RPC_URL environment variable is not set. Please set it in your environment or in a .env file."
    )


class ChainType(Enum):
    EVM = "evm"
    STARKNET = "starknet"


def get_chain_type(chain_id: int) -> ChainType:
    if chain_id == 393402133025997798000961 or chain_id == 23448594291968334:
        return ChainType.STARKNET
    return ChainType.EVM


class DryRunSyscallHandler(SyscallHandlerBase):
    """
    A handler for system calls; used by the BusinessLogic entry point execution.
    """

    def __init__(
        self,
        dict_manager: DictManager,
        segments: MemorySegmentManager,
    ):
        super().__init__(
            segments=segments,
            initial_syscall_ptr=None,
        )
        self.syscall_counter: Dict[str, int] = dict()
        self.dict_manager = dict_manager
        self.fetch_keys_registry = list()

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
            return self._handle_evm_call(request, calldata, chain_id)
        else:
            return self._handle_starknet_call(request, calldata)

    def _handle_evm_call(
        self, request: CairoStructProxy, calldata: list, chain_id: int
    ) -> CallResult:
        provider = EvmKeyProvider(RPC_URL, chain_id)
        retdata = []

        memorizerId = EvmStateId.from_int(request.contract_address)
        handlers = {
            EvmStateId.Header: (
                DryRunEvmHeaderHandler,
                EvmHeaderKey,
                EvmHeaderFunctionId,
            ),
            EvmStateId.Account: (
                DryRunEvmAccountHandler,
                EvmAccountKey,
                EvmAccountFunctionId,
            ),
            EvmStateId.Storage: (
                DryRunEvmStorageHandler,
                EvmStorageKey,
                EvmStorageFunctionId,
            ),
            EvmStateId.BlockTx: (
                DryRunEvmBlockTxHandler,
                EvmBlockTxKey,
                EvmBlockTxFunctionId,
            ),
            EvmStateId.BlockReceipt: (
                DryRunEvmBlockReceiptHandler,
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

        handler = HandlerClass(memorizer=memorizer, provider=provider)
        retdata = handler.handle(function_id=function_id, key=key)
        self.fetch_keys_registry.append(handler.fetch_keys_dict())

        return CallResult(gas_consumed=0, failure_flag=0, retdata=list(retdata))

    def _handle_starknet_call(
        self, request: CairoStructProxy, calldata: list
    ) -> CallResult:
        provider = StarknetKeyProvider(
            PROVIDER_URL_STARKNET,
            FEEDER_URL,
        )
        retdata = []

        memorizerId = StarknetStateId.from_int(request.contract_address)
        handlers = {
            StarknetStateId.Header: (
                DryRunStarknetHeaderHandler,
                StarknetHeaderKey,
                StarknetHeaderFunctionId,
            ),
            StarknetStateId.Storage: (
                DryRunStarknetStorageHandler,
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

        handler = HandlerClass(memorizer=memorizer, provider=provider)
        retdata = handler.handle(function_id=function_id, key=key)
        self.fetch_keys_registry.append(handler.fetch_keys_dict())
        retdata = [retdata]  # since we return a single felt for now

        return CallResult(gas_consumed=0, failure_flag=0, retdata=retdata)

    def clear_fetch_keys_registry(self):
        self.fetch_keys_registry.clear()

    def fetch_keys_dict(self) -> list[dict]:
        return self.fetch_keys_registry
