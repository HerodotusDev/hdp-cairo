from dataclasses import asdict
from typing import (
    Dict,
    Iterable,
    Tuple,
)
from starkware.cairo.lang.vm.relocatable import RelocatableValue, MaybeRelocatable
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from contract_bootloader.syscall_handler_base import SyscallHandlerBase
from starkware.cairo.common.dict import DictManager
from starkware.cairo.common.structs import CairoStructProxy
from starkware.starknet.business_logic.execution.objects import (
    CallResult,
)
from contract_bootloader.memorizer.memorizer import MemorizerId, Memorizer
from contract_bootloader.memorizer.account_memorizer import (
    AbstractAccountMemorizerBase,
    MemorizerFunctionId as AccountMemorizerFunctionId,
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.provider.account_key_provider import (
    AccountKeyEVMProvider,
)
from contract_bootloader.memorizer.header_memorizer import (
    MemorizerKey as HeaderMemorizerKey,
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

        memorizerId = MemorizerId.from_int(request.contract_address)
        if memorizerId == MemorizerId.Account:
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
                evm_provider_url="https://sepolia.ethereum.iosis.tech/",
            )
            retdata = handler.handle(function_id=function_id, key=key)

            self.fetch_keys_registry.append(handler.fetch_keys_dict())

        return CallResult(
            gas_consumed=0,
            failure_flag=0,
            retdata=list(retdata),
        )

    def clear_fetch_keys_registry(self):
        self.fetch_keys_registry.clear()

    def fetch_keys_dict(self) -> list[dict]:
        return self.fetch_keys_registry


class DryRunAccountMemorizerHandler(AbstractAccountMemorizerBase):
    def __init__(self, memorizer: Memorizer, evm_provider_url: str):
        super().__init__(memorizer=memorizer)
        self.evm_provider = AccountKeyEVMProvider(provider_url=evm_provider_url)
        self.fetch_keys_registry: set[AccountMemorizerKey] = set()

    def get_balance(self, key: AccountMemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_balance(key=key)
        return (
            value % 0x100000000000000000000000000000000,
            value // 0x100000000000000000000000000000000,
        )

    def fetch_keys_dict(self) -> set:
        def create_dict(key: AccountMemorizerKey):
            data = dict()
            data["key"] = key.to_dict()
            if isinstance(key, HeaderMemorizerKey):
                data["type"] = "HeaderMemorizerKey"
            elif isinstance(key, AccountMemorizerKey):
                data["type"] = "AccountMemorizerKey"
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
