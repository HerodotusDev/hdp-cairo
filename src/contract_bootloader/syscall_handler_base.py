from typing import (
    Any,
    List,
    Dict,
    Iterable,
    Optional,
    Tuple,
)
import cachetools
from starkware.starknet.core.os.syscall_handler import (
    SyscallInfo,
)
import functools
from starkware.cairo.common.structs import CairoStructProxy
from abc import ABC, abstractmethod
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from starkware.starknet.definitions.error_codes import CairoErrorCode
from starkware.starknet.core.os.syscall_utils import (
    STARKNET_SYSCALLS_COMPILED_PATH,
    cast_to_int,
    get_selector_from_program,
    get_syscall_structs,
    load_program,
    validate_runtime_request_type,
)
from starkware.starknet.core.os.syscall_utils import (
    STARKNET_SYSCALLS_COMPILED_PATH,
    cast_to_int,
    get_selector_from_program,
    get_syscall_structs,
    load_program,
    validate_runtime_request_type,
)
from starkware.starknet.business_logic.execution.objects import (
    CallResult,
)

SyscallFullResponse = Tuple[
    tuple, tuple
]  # Response header + specific syscall response.


class SyscallHandlerBase(ABC):
    def __init__(
        self,
        segments: MemorySegmentManager,
        initial_syscall_ptr: Optional[RelocatableValue],
    ):
        # Static syscall information.
        self.structs = get_syscall_structs()
        self.selector_to_syscall_info = self.get_selector_to_syscall_info()

        # Memory segments of the running program.
        self.segments = segments
        # Current syscall pointer; updated internally during the call execution.
        self._syscall_ptr = initial_syscall_ptr

    @classmethod
    @cachetools.cached(cache={})
    def get_selector_to_syscall_info(cls) -> Dict[int, SyscallInfo]:
        structs = get_syscall_structs()
        syscalls_program = load_program(path=STARKNET_SYSCALLS_COMPILED_PATH)
        get_selector = functools.partial(
            get_selector_from_program, syscalls_program=syscalls_program
        )
        return {
            get_selector("call_contract"): SyscallInfo(
                name="call_contract",
                execute_callback=cls.call_contract,
                request_struct=structs.CallContractRequest,
            ),
        }

    @property
    def syscall_ptr(self) -> RelocatableValue:
        assert (
            self._syscall_ptr is not None
        ), "syscall_ptr must be set before using the SyscallHandler."
        return self._syscall_ptr

    def syscall(self, syscall_ptr: RelocatableValue):
        """
        Executes the selected system call.
        """
        self._validate_syscall_ptr(actual_syscall_ptr=syscall_ptr)
        request_header = self._read_and_validate_request(
            request_struct=self.structs.RequestHeader
        )

        # Validate syscall selector and request.
        selector = cast_to_int(request_header.selector)
        syscall_info = self.selector_to_syscall_info.get(selector)
        assert (
            syscall_info is not None
        ), f"Unsupported syscall selector {bytes.fromhex(hex(selector)[2:])!r}"
        request = self._read_and_validate_request(
            request_struct=syscall_info.request_struct
        )
        response_header, response = syscall_info.execute_callback(
            self, request_header.gas, request
        )

        # Write response to the syscall segment.
        self._write_response(response=response_header)
        self._write_response(response=response)

    # Syscalls.

    def call_contract(
        self, remaining_gas: int, request: CairoStructProxy
    ) -> SyscallFullResponse:
        return self.call_contract_helper(
            remaining_gas=remaining_gas, request=request, syscall_name="call_contract"
        )

    def call_contract_helper(
        self, remaining_gas: int, request: CairoStructProxy, syscall_name: str
    ) -> SyscallFullResponse:
        result = self._call_contract_helper(request=request, syscall_name=syscall_name)

        response_header = self.structs.ResponseHeader(
            gas=remaining_gas, failure_flag=result.failure_flag
        )
        retdata_start = self._allocate_segment_for_retdata(retdata=result.retdata)
        retdata_end = retdata_start + len(result.retdata)
        if response_header.failure_flag == 0:
            response = self.structs.CallContractResponse(
                retdata_start=retdata_start, retdata_end=retdata_end
            )
        else:
            response = self.structs.FailureReason(start=retdata_start, end=retdata_end)

        return response_header, response

    # Application-specific syscall implementation.

    @abstractmethod
    def _call_contract_helper(
        self, request: CairoStructProxy, syscall_name: str
    ) -> CallResult:
        """
        Returns the call's result.

        syscall_name can be "call_contract" or "library_call".
        """

    # Internal utilities.

    def _get_felt_range(self, start_addr: Any, end_addr: Any) -> List[int]:
        assert isinstance(start_addr, RelocatableValue)
        assert isinstance(end_addr, RelocatableValue)
        assert start_addr.segment_index == end_addr.segment_index, (
            "Inconsistent start and end segment indices "
            f"({start_addr.segment_index} != {end_addr.segment_index})."
        )

        assert start_addr.offset <= end_addr.offset, (
            "The start offset cannot be greater than the end offset"
            f"({start_addr.offset} > {end_addr.offset})."
        )

        size = end_addr.offset - start_addr.offset
        return self.segments.memory.get_range_as_ints(addr=start_addr, size=size)

    def _handle_failure(
        self, final_gas: int, error_code: CairoErrorCode
    ) -> SyscallFullResponse:
        response_header = self.structs.ResponseHeader(gas=final_gas, failure_flag=1)
        data = [error_code.to_felt()]
        start = self.allocate_segment(data=data)
        failure_reason = self.structs.FailureReason(start=start, end=start + len(data))

        return response_header, failure_reason

    @abstractmethod
    def allocate_segment(self, data: Iterable[MaybeRelocatable]) -> RelocatableValue:
        """
        Allocates and returns a new (read-only) segment with the given data.
        Note that unlike MemorySegmentManager.write_arg, this function doesn't work well with
        recursive input - call allocate_segment for the inner items if needed.
        """

    @abstractmethod
    def _allocate_segment_for_retdata(self, retdata: Iterable[int]) -> RelocatableValue:
        """
        Allocates and returns a new (read-only) segment with the given retdata.
        """

    def _validate_syscall_ptr(self, actual_syscall_ptr: RelocatableValue):
        assert (
            actual_syscall_ptr == self.syscall_ptr
        ), f"Bad syscall_ptr, Expected {self.syscall_ptr}, got {actual_syscall_ptr}."

    def _read_and_validate_request(
        self, request_struct: CairoStructProxy
    ) -> CairoStructProxy:
        request = self._read_request(request_struct=request_struct)
        validate_runtime_request_type(
            request_values=request, request_struct=request_struct
        )
        return request

    def _read_request(self, request_struct: CairoStructProxy) -> CairoStructProxy:
        request = request_struct.from_ptr(
            memory=self.segments.memory, addr=self.syscall_ptr
        )
        # Advance syscall pointer.
        self._syscall_ptr = self.syscall_ptr + request_struct.size
        return request

    def _write_response(self, response: tuple):
        # Write response and update syscall pointer.
        self._syscall_ptr = self.segments.write_arg(ptr=self.syscall_ptr, arg=response)
