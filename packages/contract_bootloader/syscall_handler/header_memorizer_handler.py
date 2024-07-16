from rlp import decode
from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.header_memorizer import (
    AbstractHeaderMemorizerBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.block_header import BlockHeaderDencun
from tools.py.rlp import get_rlp_len
from tools.py.utils import little_8_bytes_chunks_to_bytes


class HeaderMemorizerHandler(AbstractHeaderMemorizerBase):
    def __init__(self, segments: MemorySegmentManager, memorizer: Memorizer):
        super().__init__(memorizer=memorizer)
        self.segments = segments

    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        memorizer_value_ptr = self.memorizer.read(key=key.derive())

        rlp_len = get_rlp_len(
            rlp=self.segments.memory[memorizer_value_ptr], item_start_offset=0
        )
        rlp = self._get_felt_range(
            start_addr=memorizer_value_ptr,
            end_addr=memorizer_value_ptr + (rlp_len + 7) // 8,
        )

        value = decode(
            little_8_bytes_chunks_to_bytes(rlp, rlp_len), BlockHeaderDencun
        ).as_dict()["parentHash"]

        return (
            value % 0x100000000000000000000000000000000,
            value // 0x100000000000000000000000000000000,
        )

    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
