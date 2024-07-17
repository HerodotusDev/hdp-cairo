from rlp import decode
from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.storage_memorizer import (
    AbstractStorageMemorizerBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.rlp import get_rlp_len
from tools.py.utils import little_8_bytes_chunks_to_bytes
from rlp.sedes import Binary


class StorageMemorizerHandler(AbstractStorageMemorizerBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: Memorizer):
        super().__init__(memorizer=memorizer)
        self.segments = segments

    def get_slot(self, key: MemorizerKey) -> Tuple[int, int]:
        memorizer_value_ptr = self.memorizer.read(key=key.derive())

        rlp_len = get_rlp_len(
            rlp=self.segments.memory[memorizer_value_ptr], item_start_offset=0
        )
        rlp = self._get_felt_range(
            start_addr=memorizer_value_ptr,
            end_addr=memorizer_value_ptr + (rlp_len + 7) // 8,
        )

        value = decode(
            little_8_bytes_chunks_to_bytes(rlp, rlp_len), Binary.fixed_length(32)
        )

        return (
            value % 0x100000000000000000000000000000000,
            value // 0x100000000000000000000000000000000,
        )
