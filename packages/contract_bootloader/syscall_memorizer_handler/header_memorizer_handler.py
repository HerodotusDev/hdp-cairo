from rlp import decode
from rlp.exceptions import ObjectDeserializationError
from typing import List, Tuple, Union
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.header_memorizer import (
    AbstractHeaderMemorizerBase,
    MemorizerKey,
)
from starkware.cairo.lang.vm.memory_segments import MemorySegmentManager
from tools.py.block_header import (
    BlockHeader,
    BlockHeaderDencun,
    BlockHeaderEIP1559,
    BlockHeaderShangai,
)
from tools.py.rlp import get_rlp_len
from tools.py.utils import little_8_bytes_chunks_to_bytes, split_128


def decode_block_header(
    rlp: bytes,
) -> Union[BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun]:
    # Try decoding with multiple formats
    for block_header_cls in [
        BlockHeaderDencun,
        BlockHeaderShangai,
        BlockHeaderEIP1559,
        BlockHeader,
    ]:
        try:
            decoded_header = decode(rlp, block_header_cls)
            # Check for key fields that identify the format
            if (
                "baseFeePerGas" in decoded_header.as_dict()
                and block_header_cls == BlockHeaderDencun
            ):
                return decoded_header.as_dict()
            elif (
                "withdrawalsRoot" in decoded_header.as_dict()
                and block_header_cls == BlockHeaderShangai
            ):
                return decoded_header.as_dict()
            elif (
                "baseFeePerGas" in decoded_header.as_dict()
                and block_header_cls == BlockHeaderEIP1559
            ):
                return decoded_header.as_dict()
            elif (
                "parentHash" in decoded_header.as_dict()
                and block_header_cls == BlockHeader
            ):
                return decoded_header.as_dict()
        except ObjectDeserializationError:
            continue
    raise ValueError("Unsupported block header format or invalid RLP data.")


class HeaderMemorizerHandler(AbstractHeaderMemorizerBase):
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

    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "parentHash"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "unclesHash"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "coinbase"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "stateRoot"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "transactionsRoot"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "receiptsRoot"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "difficulty"
            ]
        )
        return split_128(value)

    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))["number"]
        )
        return split_128(value)

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "gasLimit"
            ]
        )
        return split_128(value)

    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))["gasUsed"]
        )
        return split_128(value)

    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "timestamp"
            ]
        )
        return split_128(value)

    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "mixHash"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "nonce"
            ].hex(),
            16,
        )
        return split_128(value)

    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        rlp_len, rlp = self.extract_rlp(key=key)
        value = int(
            decode_block_header(little_8_bytes_chunks_to_bytes(rlp, rlp_len))[
                "baseFeePerGas"
            ]
        )
        return split_128(value)

    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
