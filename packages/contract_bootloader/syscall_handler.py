from typing import Iterable
from starkware.starknet.core.os.syscall_handler import (
    SyscallHandlerBase,
)
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager


class SyscallHandler(SyscallHandlerBase):
    """
    A handler for system calls; used by the BusinessLogic entry point execution.
    """

    def __init__(
        self,
        segments: MemorySegmentManager,
    ):
        super().__init__(segments=segments, initial_syscall_ptr=None)

    def set_syscall_ptr(self, syscall_ptr: RelocatableValue):
        assert self._syscall_ptr is None, "syscall_ptr is already set."
        self._syscall_ptr = syscall_ptr

    def allocate_segment(self, data: Iterable[MaybeRelocatable]) -> RelocatableValue:
        segment_start = self.segments.add()
        self.segments.write_arg(ptr=segment_start, arg=data)
        return segment_start

    def _allocate_segment_for_retdata(self):
        # Implementation here
        pass

    def _call_contract_helper(self):
        # Implementation here
        pass

    def _count_syscall(self):
        # Implementation here
        pass

    def _deploy(self):
        # Implementation here
        pass

    def _emit_event(self):
        # Implementation here
        pass

    def _get_block_hash(self):
        # Implementation here
        pass

    def _get_execution_info_ptr(self):
        # Implementation here
        pass

    def _keccak(self):
        # Implementation here
        pass

    def _replace_class(self):
        # Implementation here
        pass

    def _send_message_to_l1(self):
        # Implementation here
        pass

    def _storage_read(self):
        # Implementation here
        pass

    def _storage_write(self):
        # Implementation here
        pass

    def current_block_number(self):
        # Implementation here
        pass
