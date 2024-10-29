from typing import List, Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.header import (
    AbstractEvmHeaderBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.types.evm.header import FeltBlockHeader
from tools.py.rlp import get_rlp_len


class EvmHeaderHandler(AbstractEvmHeaderBase):
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

    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).parent_hash()

    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).uncles_hash()

    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).coinbase()

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).state_root()

    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).transactions_root()

    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).receipts_root()

    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).difficulty()

    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).number()

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).gas_limit()

    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).gas_used()

    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).timestamp()

    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).mix_hash()

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).nonce()

    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).base_fee_per_gas()

    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).withdrawals_root()

    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).blob_gas_used()

    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).excess_blob_gas()

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltBlockHeader.from_rlp_chunks(rlp, rlp_len).parent_beacon_block_root()
