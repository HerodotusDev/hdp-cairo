import os
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

# Load environment variables from a .env file if present
from dotenv import load_dotenv
from tools.py.providers.evm.provider import EvmKeyProvider

load_dotenv()

RPC_URL = os.getenv("RPC_URL", "")
EVM_CHAIN_ID = os.getenv("EVM_CHAIN_ID", 1)

if not RPC_URL:
    raise ValueError(
        "RPC_URL environment variable is not set. Please set it in your environment or in a .env file."
    )


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

        retdata = []
        provider = EvmKeyProvider(RPC_URL, EVM_CHAIN_ID)

        memorizerId = EvmStateId.from_int(request.contract_address)
        if memorizerId == EvmStateId.Header:
            total_size = EvmMemorizer.size() + EvmHeaderKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = EvmHeaderFunctionId.from_int(request.selector)
            memorizer = EvmMemorizer(
                dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = EvmMemorizer.size()
            key = EvmHeaderKey.from_int(calldata[idx : idx + EvmHeaderKey.size()])

            handler = DryRunEvmHeaderHandler(
                memorizer=memorizer,
                provider=provider,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == EvmStateId.Account:
            total_size = EvmMemorizer.size() + EvmAccountKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = EvmAccountFunctionId.from_int(request.selector)
            memorizer = EvmMemorizer(
                dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = EvmMemorizer.size()
            key = EvmAccountKey.from_int(calldata[idx : idx + EvmAccountKey.size()])

            handler = DryRunEvmAccountHandler(
                memorizer=memorizer,
                provider=provider,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == EvmStateId.Storage:
            total_size = EvmMemorizer.size() + EvmStorageKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = EvmStorageFunctionId.from_int(request.selector)
            memorizer = EvmMemorizer(
                dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = EvmMemorizer.size()
            key = EvmStorageKey.from_int(calldata[idx : idx + EvmStorageKey.size()])

            handler = DryRunEvmStorageHandler(
                memorizer=memorizer,
                provider=provider,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == EvmStateId.BlockTx:
            total_size = EvmMemorizer.size() + EvmBlockTxKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = EvmBlockTxFunctionId.from_int(request.selector)
            memorizer = EvmMemorizer(
                dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = EvmMemorizer.size()
            key = EvmBlockTxKey.from_int(calldata[idx : idx + EvmBlockTxKey.size()])

            handler = DryRunEvmBlockTxHandler(
                memorizer=memorizer,
                provider=provider,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == EvmStateId.BlockReceipt:
            total_size = EvmMemorizer.size() + EvmBlockReceiptKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = EvmBlockReceiptFunctionId.from_int(request.selector)
            memorizer = EvmMemorizer(
                dict_raw_ptrs=calldata[0 : EvmMemorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = EvmMemorizer.size()
            key = EvmBlockReceiptKey.from_int(
                calldata[idx : idx + EvmBlockReceiptKey.size()]
            )

            handler = DryRunEvmBlockReceiptHandler(
                memorizer=memorizer,
                provider=provider,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        else:
            raise ValueError(f"EvmStateId {memorizerId} not matched")

        return CallResult(
            gas_consumed=0,
            failure_flag=0,
            retdata=list(retdata),
        )

    def clear_fetch_keys_registry(self):
        self.fetch_keys_registry.clear()

    def fetch_keys_dict(self) -> list[dict]:
        return self.fetch_keys_registry
