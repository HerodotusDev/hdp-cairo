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
from contract_bootloader.memorizer.memorizer import MemorizerId, Memorizer
from contract_bootloader.memorizer.account_memorizer import (
    MemorizerFunctionId as AccountMemorizerFunctionId,
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.memorizer.header_memorizer import (
    MemorizerFunctionId as HeaderMemorizerFunctionId,
    MemorizerKey as HeaderMemorizerKey,
)
from contract_bootloader.memorizer.storage_memorizer import (
    MemorizerFunctionId as StorageMemorizerFunctionId,
    MemorizerKey as StorageMemorizerKey,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.header_memorizer_handler import (
    DryRunHeaderMemorizerHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.account_memorizer_handler import (
    DryRunAccountMemorizerHandler,
)
from contract_bootloader.dryrun_syscall_memorizer_handler.storage_memorizer_handler import (
    DryRunStorageMemorizerHandler,
)

# Load environment variables from a .env file if present
from dotenv import load_dotenv

load_dotenv()

RPC_URL = os.getenv("RPC_URL", "")

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

        memorizerId = MemorizerId.from_int(request.contract_address)
        if memorizerId == MemorizerId.Header:
            total_size = Memorizer.size() + HeaderMemorizerKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = HeaderMemorizerFunctionId.from_int(request.selector)
            memorizer = Memorizer(
                dict_raw_ptrs=calldata[0 : Memorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = Memorizer.size()
            key = HeaderMemorizerKey.from_int(
                calldata[idx : idx + HeaderMemorizerKey.size()]
            )

            handler = DryRunHeaderMemorizerHandler(
                memorizer=memorizer,
                evm_provider_url=RPC_URL,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == MemorizerId.Account:
            total_size = Memorizer.size() + AccountMemorizerKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = AccountMemorizerFunctionId.from_int(request.selector)
            memorizer = Memorizer(
                dict_raw_ptrs=calldata[0 : Memorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = Memorizer.size()
            key = AccountMemorizerKey.from_int(
                calldata[idx : idx + AccountMemorizerKey.size()]
            )

            handler = DryRunAccountMemorizerHandler(
                memorizer=memorizer,
                evm_provider_url=RPC_URL,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        elif memorizerId == MemorizerId.Storage:
            total_size = Memorizer.size() + StorageMemorizerKey.size()

            if len(calldata) != total_size:
                raise ValueError(
                    f"Memorizer read must be initialized with a list of {total_size} integers"
                )

            function_id = StorageMemorizerFunctionId.from_int(request.selector)
            memorizer = Memorizer(
                dict_raw_ptrs=calldata[0 : Memorizer.size()],
                dict_manager=self.dict_manager,
            )

            idx = Memorizer.size()
            key = StorageMemorizerKey.from_int(
                calldata[idx : idx + StorageMemorizerKey.size()]
            )

            handler = DryRunStorageMemorizerHandler(
                memorizer=memorizer,
                evm_provider_url=RPC_URL,
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        else:
            raise ValueError(f"MemorizerId {memorizerId} not matched")

        return CallResult(
            gas_consumed=0,
            failure_flag=0,
            retdata=list(retdata),
        )

    def clear_fetch_keys_registry(self):
        self.fetch_keys_registry.clear()

    def fetch_keys_dict(self) -> list[dict]:
        return self.fetch_keys_registry
