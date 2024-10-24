from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from tools.py.types.evm.base_felt import BaseFelt
from web3.types import BlockData
from rlp.sedes import (
    BigEndianInt,
    big_endian_int,
    Binary,
    binary,
)
from web3 import Web3
from typing import List, Union, Tuple
from tools.py.utils import little_8_bytes_chunks_to_bytes

address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)
int256 = BigEndianInt(256)
trie_root = Binary.fixed_length(32, allow_empty=True)


class LegacyBlockHeader(Serializable):
    fields = (
        ("parentHash", hash32),
        ("unclesHash", hash32),
        ("coinbase", address),
        ("stateRoot", trie_root),
        ("transactionsRoot", trie_root),
        ("receiptsRoot", trie_root),
        ("logsBloom", int256),
        ("difficulty", big_endian_int),
        ("number", big_endian_int),
        ("gasLimit", big_endian_int),
        ("gasUsed", big_endian_int),
        ("timestamp", big_endian_int),
        ("extraData", binary),
        ("mixHash", binary),
        ("nonce", Binary(8, allow_empty=True)),
    )

    def hash(self) -> HexBytes:
        # Instance method now instead of classmethod
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        # Instance method now instead of classmethod
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> "LegacyBlockHeader":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "LegacyBlockHeader":
        return cls(
            HexBytes(block["parentHash"]),
            HexBytes(block["sha3Uncles"]),
            bytearray.fromhex(block["miner"][2:]),
            HexBytes(block["stateRoot"]),
            HexBytes(block["transactionsRoot"]),
            HexBytes(block["receiptsRoot"]),
            int.from_bytes(HexBytes(block["logsBloom"]), "big"),
            int(block["difficulty"], 16),
            int(block["number"], 16),
            int(block["gasLimit"], 16),
            int(block["gasUsed"], 16),
            int(block["timestamp"], 16),
            HexBytes(block["extraData"]),
            HexBytes(block["mixHash"]),
            HexBytes(block["nonce"]),
        )


class BlockHeaderEIP1559(Serializable):
    fields = (
        ("parentHash", hash32),
        ("unclesHash", hash32),
        ("coinbase", address),
        ("stateRoot", trie_root),
        ("transactionsRoot", trie_root),
        ("receiptsRoot", trie_root),
        ("logsBloom", int256),
        ("difficulty", big_endian_int),
        ("number", big_endian_int),
        ("gasLimit", big_endian_int),
        ("gasUsed", big_endian_int),
        ("timestamp", big_endian_int),
        ("extraData", binary),
        ("mixHash", binary),
        ("nonce", Binary(8, allow_empty=True)),
        ("baseFeePerGas", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> "BlockHeaderEIP1559":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "BlockHeaderEIP1559":
        return cls(
            HexBytes(block["parentHash"]),
            HexBytes(block["sha3Uncles"]),
            bytearray.fromhex(block["miner"][2:]),
            HexBytes(block["stateRoot"]),
            HexBytes(block["transactionsRoot"]),
            HexBytes(block["receiptsRoot"]),
            int.from_bytes(HexBytes(block["logsBloom"]), "big"),
            int(block["difficulty"], 16),
            int(block["number"], 16),
            int(block["gasLimit"], 16),
            int(block["gasUsed"], 16),
            int(block["timestamp"], 16),
            HexBytes(block["extraData"]),
            HexBytes(block["mixHash"]),
            HexBytes(block["nonce"]),
            int(block["baseFeePerGas"], 16),
        )


class BlockHeaderShangai(Serializable):
    fields = (
        ("parentHash", hash32),
        ("unclesHash", hash32),
        ("coinbase", address),
        ("stateRoot", trie_root),
        ("transactionsRoot", trie_root),
        ("receiptsRoot", trie_root),
        ("logsBloom", int256),
        ("difficulty", big_endian_int),
        ("number", big_endian_int),
        ("gasLimit", big_endian_int),
        ("gasUsed", big_endian_int),
        ("timestamp", big_endian_int),
        ("extraData", binary),
        ("mixHash", binary),
        ("nonce", Binary(8, allow_empty=True)),
        ("baseFeePerGas", big_endian_int),
        ("withdrawalsRoot", trie_root),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> "BlockHeaderShangai":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "BlockHeaderShangai":
        return cls(
            HexBytes(block["parentHash"]),
            HexBytes(block["sha3Uncles"]),
            bytearray.fromhex(block["miner"][2:]),
            HexBytes(block["stateRoot"]),
            HexBytes(block["transactionsRoot"]),
            HexBytes(block["receiptsRoot"]),
            int.from_bytes(HexBytes(block["logsBloom"]), "big"),
            int(block["difficulty"], 16),
            int(block["number"], 16),
            int(block["gasLimit"], 16),
            int(block["gasUsed"], 16),
            int(block["timestamp"], 16),
            HexBytes(block["extraData"]),
            HexBytes(block["mixHash"]),
            HexBytes(block["nonce"]),
            int(block["baseFeePerGas"], 16),
            HexBytes(block["withdrawalsRoot"]),
        )


class BlockHeaderDencun(Serializable):
    fields = (
        ("parentHash", hash32),
        ("unclesHash", hash32),
        ("coinbase", address),
        ("stateRoot", trie_root),
        ("transactionsRoot", trie_root),
        ("receiptsRoot", trie_root),
        ("logsBloom", int256),
        ("difficulty", big_endian_int),
        ("number", big_endian_int),
        ("gasLimit", big_endian_int),
        ("gasUsed", big_endian_int),
        ("timestamp", big_endian_int),
        ("extraData", binary),
        ("mixHash", binary),
        ("nonce", Binary(8, allow_empty=True)),
        ("baseFeePerGas", big_endian_int),
        ("withdrawalsRoot", trie_root),
        ("blobGasUsed", big_endian_int),
        ("excessBlobGas", big_endian_int),
        ("parentBeaconBlockRoot", binary),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> "BlockHeaderDencun":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "BlockHeaderDencun":
        return cls(
            HexBytes(block["parentHash"]),
            HexBytes(block["sha3Uncles"]),
            bytearray.fromhex(block["miner"][2:]),
            HexBytes(block["stateRoot"]),
            HexBytes(block["transactionsRoot"]),
            HexBytes(block["receiptsRoot"]),
            int.from_bytes(HexBytes(block["logsBloom"]), "big"),
            int(block["difficulty"], 16),
            int(block["number"], 16),
            int(block["gasLimit"], 16),
            int(block["gasUsed"], 16),
            int(block["timestamp"], 16),
            HexBytes(block["extraData"]),
            HexBytes(block["mixHash"]),
            HexBytes(block["nonce"]),
            int(block["baseFeePerGas"], 16),
            HexBytes(block["withdrawalsRoot"]),
            int(block["blobGasUsed"], 16),
            int(block["excessBlobGas"], 16),
            HexBytes(block["parentBeaconBlockRoot"]),
        )


class BlockHeader:
    def __init__(self):
        self.header: Union[
            LegacyBlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun
        ] = None

    @property
    def hash(self) -> HexBytes:
        return self.header.hash()

    @property
    def parent_hash(self) -> HexBytes:
        return HexBytes(self.header.parentHash)

    @property
    def uncles_hash(self) -> HexBytes:
        return HexBytes(self.header.unclesHash)

    @property
    def coinbase(self) -> HexBytes:
        return HexBytes(self.header.coinbase)

    @property
    def state_root(self) -> HexBytes:
        return HexBytes(self.header.stateRoot)

    @property
    def transactions_root(self) -> HexBytes:
        return HexBytes(self.header.transactionsRoot)

    @property
    def receipts_root(self) -> HexBytes:
        return HexBytes(self.header.receiptsRoot)

    @property
    def logs_bloom(self) -> int:
        return self.header.logsBloom

    @property
    def difficulty(self) -> int:
        return self.header.difficulty

    @property
    def number(self) -> int:
        return self.header.number

    @property
    def gas_limit(self) -> int:
        return self.header.gasLimit

    @property
    def gas_used(self) -> int:
        return self.header.gasUsed

    @property
    def timestamp(self) -> int:
        return self.header.timestamp

    @property
    def extra_data(self) -> bytes:
        return self.header.extraData

    @property
    def mix_hash(self) -> HexBytes:
        return HexBytes(self.header.mixHash)

    @property
    def nonce(self) -> bytes:
        return self.header.nonce

    @property
    def base_fee_per_gas(self) -> int:
        if isinstance(
            self.header, (BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun)
        ):
            return self.header.baseFeePerGas
        raise AttributeError(
            "base_fee_per_gas is not available for this block header type"
        )

    @property
    def withdrawals_root(self) -> HexBytes:
        if isinstance(self.header, (BlockHeaderShangai, BlockHeaderDencun)):
            return HexBytes(self.header.withdrawalsRoot)
        raise AttributeError(
            "withdrawals_root is not available for this block header type"
        )

    @property
    def blob_gas_used(self) -> int:
        if isinstance(self.header, BlockHeaderDencun):
            return self.header.blobGasUsed
        raise AttributeError(
            "blob_gas_used is not available for this block header type"
        )

    @property
    def excess_blob_gas(self) -> int:
        if isinstance(self.header, BlockHeaderDencun):
            return self.header.excessBlobGas
        raise AttributeError(
            "excess_blob_gas is not available for this block header type"
        )

    @property
    def parent_beacon_block_root(self) -> HexBytes:
        if isinstance(self.header, BlockHeaderDencun):
            return HexBytes(self.header.parentBeaconBlockRoot)
        raise AttributeError(
            "parent_beacon_block_root is not available for this block header type"
        )

    @property
    def type(self) -> int:
        if isinstance(self.header, LegacyBlockHeader):
            return 0
        elif isinstance(self.header, BlockHeaderEIP1559):
            return 1
        elif isinstance(self.header, BlockHeaderShangai):
            return 2
        elif isinstance(self.header, BlockHeaderDencun):
            return 3

    def raw_rlp(self) -> bytes:
        return self.header.raw_rlp()

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "BlockHeader":
        instance = cls()
        if "excessBlobGas" in block:
            instance.header = BlockHeaderDencun.from_rpc_data(block)
        elif "withdrawalsRoot" in block:
            instance.header = BlockHeaderShangai.from_rpc_data(block)
        elif "baseFeePerGas" in block:
            instance.header = BlockHeaderEIP1559.from_rpc_data(block)
        else:
            instance.header = LegacyBlockHeader.from_rpc_data(block)
        return instance

    @classmethod
    def from_rlp(cls, data: bytes) -> "BlockHeader":
        decoded = decode(data)
        num_fields = len(decoded)
        instance = cls()

        if num_fields == 15:
            instance.header = LegacyBlockHeader.from_rlp(data)
        elif num_fields == 16:
            instance.header = BlockHeaderEIP1559.from_rlp(data)
        elif num_fields == 17:
            instance.header = BlockHeaderShangai.from_rlp(data)
        elif num_fields == 20:
            instance.header = BlockHeaderDencun.from_rlp(data)
        else:
            raise ValueError(f"Unknown block header type with {num_fields} fields")
        return instance


# Automatically splits the fields into two 128 bit felt
class FeltBlockHeader(BaseFelt):
    def __init__(self, block_header: BlockHeader):
        self.header = block_header

    def hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.hash, as_le)

    def parent_hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.parent_hash, as_le)

    def uncles_hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.uncles_hash, as_le)

    def coinbase(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.coinbase, as_le)

    def state_root(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.state_root, as_le)

    def transactions_root(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.transactions_root, as_le)

    def receipts_root(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.receipts_root, as_le)

    # ToDo: figure out what to do here
    # @property
    # def logs_bloom(self) -> Tuple[int, int]:
    #     return self._split_word_to_felt(self.header.logs_bloom, as_le)

    def difficulty(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.difficulty, as_le)

    def number(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.number, as_le)

    def gas_limit(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.gas_limit, as_le)

    def gas_used(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.gas_used, as_le)

    def timestamp(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.timestamp, as_le)

    def extra_data(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.extra_data, as_le)

    def mix_hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.mix_hash, as_le)

    def nonce(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.nonce, as_le)

    def base_fee_per_gas(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.base_fee_per_gas, as_le)

    def withdrawals_root(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.withdrawals_root, as_le)

    def blob_gas_used(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.blob_gas_used, as_le)

    def excess_blob_gas(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.excess_blob_gas, as_le)

    def parent_beacon_block_root(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.header.parent_beacon_block_root, as_le)

    @classmethod
    def from_rlp_chunks(cls, rlp_chunks: List[int], rlp_len: int) -> "FeltBlockHeader":
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(BlockHeader.from_rlp(rlp))

    @classmethod
    def from_rpc_data(cls, block: BlockData) -> "FeltBlockHeader":
        return cls(BlockHeader.from_rpc_data(block))
