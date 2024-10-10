from rlp import decode
from typing import List, Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.block_tx_memorizer import (
    AbstractBlockTxMemorizerBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.rlp import get_rlp_len
from tools.py.utils import little_8_bytes_chunks_to_bytes, split_128
from rlp.sedes import big_endian_int


class BlockTxMemorizerHandler(AbstractBlockTxMemorizerBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: Memorizer):
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

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_gas_price(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_receiver(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_value(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_input(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_v(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_r(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_s(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_chain_id(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_access_list(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_blob_versioned_hashes(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_tx_type(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
