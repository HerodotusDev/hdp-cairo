from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from web3.types import BlockData
from rlp.sedes import (
    BigEndianInt,
    big_endian_int,
    Binary,
    binary,
)
from web3 import Web3
from typing import Union


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

    @classmethod
    def hash(self) -> HexBytes:
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    @classmethod
    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> 'LegacyBlockHeader':
        return decode(data, cls)

    @classmethod
    def from_block_data(cls, block: BlockData) -> 'LegacyBlockHeader':
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

    @classmethod
    def hash(self) -> HexBytes:
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    @classmethod
    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> 'BlockHeaderEIP1559':
        return decode(data, cls)

    @classmethod
    def from_block_data(cls, block: BlockData) -> 'BlockHeaderEIP1559':
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

    @classmethod
    def hash(self) -> HexBytes:
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    @classmethod
    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> 'BlockHeaderShangai':
        return decode(data, cls)

    @classmethod
    def from_block_data(cls, block: BlockData) -> 'BlockHeaderShangai':
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

    @classmethod
    def hash(self) -> HexBytes:
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    @classmethod
    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> 'BlockHeaderDencun':
        return decode(data, cls)

    @classmethod
    def from_block_data(cls, block: BlockData) -> 'BlockHeaderDencun':
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


class BlockHeader(Serializable):
    @classmethod
    def from_block_data(cls, block: BlockData) -> Union[LegacyBlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun]:
        if "excessBlobGas" in block:
            return BlockHeaderDencun.from_block_data(block)
        elif "withdrawalsRoot" in block:
            return BlockHeaderShangai.from_block_data(block)
        elif "baseFeePerGas" in block:
            return BlockHeaderEIP1559.from_block_data(block)
        else:
            return LegacyBlockHeader.from_block_data(block)

    @classmethod
    def from_rlp(cls, data: bytes) -> Union[LegacyBlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun]:
        decoded = decode(data)
        num_fields = len(decoded)

        if num_fields == 15:
            return LegacyBlockHeader.decode(data)
        elif num_fields == 16:
            return BlockHeaderEIP1559.decode(data)
        elif num_fields == 17:
            return BlockHeaderShangai.decode(data)
        elif num_fields == 20:
            return BlockHeaderDencun.decode(data)
        else:
            raise ValueError(f"Unknown block header type with {num_fields} fields")
