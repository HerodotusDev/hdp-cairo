from typing import List, Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.evm.block_tx import (
    AbstractEvmBlockTxBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.types.evm.tx import FeltTx
from tools.py.rlp import get_rlp_len


class EvmBlockTxHandler(AbstractEvmBlockTxBase):
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
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).nonce()

    def get_gas_price(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).gas_price()

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).gas_limit()

    def get_to(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).to()

    def get_value(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).value()

    def get_data(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_v(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).v()

    def get_r(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).r()

    def get_s(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).s()

    def get_chain_id(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).chain_id()

    def get_access_list(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).max_priority_fee_per_gas()

    def get_max_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).max_fee_per_gas()

    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        return FeltTx.from_rlp_chunks(rlp, rlp_len).max_fee_per_blob_gas()

    def get_blob_versioned_hashes(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
