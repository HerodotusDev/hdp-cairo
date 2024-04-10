from hexbytes.main import HexBytes
from rlp import Serializable, encode
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


class BlockHeader(Serializable):
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
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    def raw_rlp(self) -> bytes:
        return encode(self)


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
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    def raw_rlp(self) -> bytes:
        return encode(self)


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
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    def raw_rlp(self) -> bytes:
        return encode(self)


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
        _rlp = encode(self)
        return Web3.keccak(_rlp)

    def raw_rlp(self) -> bytes:
        return encode(self)


def build_block_header(
    block: BlockData,
) -> Union[BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai]:
    if "excessBlobGas" in block.keys():
        header = BlockHeaderDencun(
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
    elif "withdrawalsRoot" in block.keys():
        header = BlockHeaderShangai(
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
    elif "baseFeePerGas" in block.keys():
        header = BlockHeaderEIP1559(
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
    else:
        header = BlockHeader(
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
    return header
