from typing import List
from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from contract_bootloader.memorizer.starknet.storage import (
    AbstractStarknetStorageBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager


class StarknetStorageHandler(AbstractStarknetStorageBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: StarknetMemorizer):
        super().__init__(memorizer=memorizer)
        self.segments = segments

    def extract_value(self, key: MemorizerKey) -> int:
        memorizer_value_ptr = self.memorizer.read(key=key.derive())
        return self.segments.memory[memorizer_value_ptr]

    def get_slot(self, key: MemorizerKey) -> int:
        return self.extract_value(key)
