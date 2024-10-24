from typing import List, Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.storage import (
    AbstractEvmStorageBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.rlp import get_rlp_len
from tools.py.types.evm.storage import FeltStorage


class EvmStorageHandler(AbstractEvmStorageBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: EvmMemorizer):
        super().__init__(memorizer=memorizer)
        self.segments = segments

    def extract_rlp(self, key: MemorizerKey) -> Tuple[int, List[int]]:
        memorizer_value_ptr = self.memorizer.read(key=key.derive())
        rlp_len = get_rlp_len(
            rlp=self.segments.memory[memorizer_value_ptr], item_start_offset=0
        )
        rlp = self._get_felt_range(
            start_addr=memorizer_value_ptr,
            end_addr=memorizer_value_ptr + (rlp_len + 7) // 8,
        )
        return (rlp_len, rlp)

    def get_slot(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltStorage.from_rlp_chunks(rlp, rlp_len).value
