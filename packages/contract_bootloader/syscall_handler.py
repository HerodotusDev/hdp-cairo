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
from contract_bootloader.memorizer.header_memorizer import (
    MemorizerFunctionId as HeaderMemorizerFunctionId,
    MemorizerKey as HeaderMemorizerKey,
)
from contract_bootloader.memorizer.account_memorizer import (
    MemorizerFunctionId as AccountMemorizerFunctionId,
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.memorizer.storage_memorizer import (
    MemorizerFunctionId as StorageMemorizerFunctionId,
    MemorizerKey as StorageMemorizerKey,
)
from contract_bootloader.syscall_memorizer_handler.account_memorizer_handler import (
    AccountMemorizerHandler,
)
from contract_bootloader.syscall_memorizer_handler.header_memorizer_handler import (
    HeaderMemorizerHandler,
)
from contract_bootloader.syscall_memorizer_handler.storage_memorizer_handler import (
    StorageMemorizerHandler,
)


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

            handler = HeaderMemorizerHandler(
                segments=self.segments,
                memorizer=memorizer,
            )
            retdata = handler.handle(function_id=function_id, key=key)

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

            handler = AccountMemorizerHandler(
                segments=self.segments,
                memorizer=memorizer,
            )
            retdata = handler.handle(function_id=function_id, key=key)

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
            print(memorizer.dict_ptr)

            idx = Memorizer.size()
            key = StorageMemorizerKey.from_int(
                calldata[idx : idx + StorageMemorizerKey.size()]
            )

            handler = StorageMemorizerHandler(
                segments=self.segments,
                memorizer=memorizer,
            )
            retdata = handler.handle(function_id=function_id, key=key)

        else:
            raise ValueError(f"MemorizerId {memorizerId} not matched")

        return CallResult(
            gas_consumed=0,
            failure_flag=0,
            retdata=list(retdata),
        )
