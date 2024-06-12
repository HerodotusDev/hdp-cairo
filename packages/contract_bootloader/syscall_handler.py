from typing import (
    Dict,
    Iterable,
)
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from contract_bootloader.syscall_handler_base import SyscallHandlerBase
from starkware.cairo.common.dict import DictManager
from starkware.cairo.common.structs import CairoStructProxy
from starkware.starknet.business_logic.execution.objects import (
    CallResult,
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
        selector = request.selector
        print("selector", selector)

        calldata = self._get_felt_range(
            start_addr=request.calldata_start, end_addr=request.calldata_end
        )

        dict_segment = calldata[0]
        dict_offset = calldata[1]
        list_segment = calldata[2]
        list_offset = calldata[3]
        dict_key = calldata[4]

        dict_ptr = RelocatableValue.from_tuple([dict_segment, dict_offset])
        dictionary = self.dict_manager.get_dict(dict_ptr)

        index = int(dictionary[dict_key])

        list_ptr = RelocatableValue.from_tuple([list_segment, list_offset])
        rlp_ptr = self.segments.memory[list_ptr + index * 6]
        rlp_len = self.segments.memory[list_ptr + index * 6 + 1]

        rlp = self._get_felt_range(start_addr=rlp_ptr, end_addr=rlp_ptr + rlp_len)

        print("rlp", rlp)

        return CallResult(
            gas_consumed=0,
            failure_flag=0,
            retdata=[0],
        )
