from rlp import decode
from typing import List, Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.account_memorizer import (
    AbstractAccountMemorizerBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.account import Account
from tools.py.rlp import get_rlp_len
from tools.py.utils import little_8_bytes_chunks_to_bytes, split_128


class AccountMemorizerHandler(AbstractAccountMemorizerBase):
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
        value = int(
            decode(little_8_bytes_chunks_to_bytes(rlp, rlp_len), Account).as_dict()[
                "nonce"
            ]
        )
        return split_128(value)

    def get_balance(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode(little_8_bytes_chunks_to_bytes(rlp, rlp_len), Account).as_dict()[
                "balance"
            ]
        )
        return split_128(value)

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode(little_8_bytes_chunks_to_bytes(rlp, rlp_len), Account)
            .as_dict()["storageRoot"]
            .hex(),
            16,
        )
        return split_128(value)

    def get_code_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode(little_8_bytes_chunks_to_bytes(rlp, rlp_len), Account)
            .as_dict()["codeHash"]
            .hex(),
            16,
        )
        return split_128(value)
