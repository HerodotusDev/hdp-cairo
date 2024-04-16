from hexbytes.main import HexBytes
from rlp import Serializable, encode
from web3.types import BlockData, SignedTx
from rlp.sedes import (
    BigEndianInt,
    big_endian_int,
    Binary,
    binary,
    lists,
)
from web3 import Web3
from typing import Union


address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)
int256 = BigEndianInt(256)
trie_root = Binary.fixed_length(32, allow_empty=True)


class LegacyTx(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("to", address),
        ("value", big_endian_int),
        ("data", binary),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
        ("sender", address),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.v,
                self.r,
                self.s,
            ]
        )

    def signed_rlp(self) -> bytes:
        return encode(
            [self.nonce, self.gas_price, self.gas_limit, self.to, self.value, self.data]
        )


class Eip155(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("to", address),
        ("value", big_endian_int),
        ("data", binary),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
        ("chain_id", big_endian_int),
        ("sender", address),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.v,
                self.r,
                self.s,
            ]
        )

    def signed_rlp(self) -> bytes:
        return encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.chain_id,
                0,
                0,
            ]
        )


class Eip2930(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("to", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", lists.CountableList(address)),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
        ("sender", address),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return bytes.fromhex("01") + encode(
            [
                self.chain_id,
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
                self.v,
                self.r,
                self.s,
            ]
        )

    def signed_rlp(self) -> bytes:
        return encode(
            [
                self.chain_id,
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
            ]
        )


class Eip1559(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("max_priority_fee_per_gas", big_endian_int),
        ("max_fee_per_gas", big_endian_int),
        ("gas_limit", big_endian_int),
        ("to", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", lists.CountableList(address)),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
        ("sender", address),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return bytes.fromhex("02") + encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
                self.v,
                self.r,
                self.s,
            ]
        )

    def signed_rlp(self) -> bytes:
        return encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
            ]
        )


class Eip4844(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("max_priority_fee_per_gas", big_endian_int),
        ("max_fee_per_gas", big_endian_int),
        ("gas_limit", big_endian_int),
        ("to", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", lists.CountableList(address)),
        ("max_fee_per_blob_gas", big_endian_int),
        ("blob_versioned_hashes", lists.CountableList(hash32)),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
        ("sender", address),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return bytes.fromhex("03") + encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
                self.max_fee_per_blob_gas,
                self.blob_versioned_hashes,
                self.v,
                self.r,
                self.s,
            ]
        )

    def signed_rlp(self) -> bytes:
        return encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.to,
                self.value,
                self.data,
                self.access_list,
                self.max_fee_per_blob_gas,
                self.blob_versioned_hashes,
            ]
        )


def build_tx(tx: SignedTx) -> Union[LegacyTx]:
    if tx["type"] == "0x0":
        if int(tx["blockNumber"], 16) < 2675000:
            return LegacyTx(
                int(tx["nonce"], 16),
                int(tx["gasPrice"], 16),
                int(tx["gas"], 16),
                HexBytes(tx["to"]),
                int(tx["value"], 16),
                HexBytes(tx["input"]),
                int(tx["v"], 16),
                HexBytes(tx["r"]),
                HexBytes(tx["s"]),
                HexBytes(tx["from"]),
                int(tx["type"], 16),
                int(tx["blockNumber"], 16),
            )
        else:
            # EIP-155 tx
            return Eip155(
                int(tx["nonce"], 16),
                int(tx["gasPrice"], 16),
                int(tx["gas"], 16),
                HexBytes(tx["to"]),
                int(tx["value"], 16),
                HexBytes(tx["input"]),
                int(tx["v"], 16),
                HexBytes(tx["r"]),
                HexBytes(tx["s"]),
                int(tx["chainId"], 16),
                HexBytes(tx["from"]),
                int(tx["type"], 16),
                int(tx["blockNumber"], 16),
            )
    elif tx["type"] == "0x1":
        # EIP-2930 tx
        return Eip2930(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["gasPrice"], 16),
            int(tx["gas"], 16),
            HexBytes(tx["to"]),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            [HexBytes(address) for address in tx["accessList"]],
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
            HexBytes(tx["from"]),
            int(tx["type"], 16),
            int(tx["blockNumber"], 16),
        )
    elif tx["type"] == "0x2":
        # EIP-1559 tx
        return Eip1559(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["maxPriorityFeePerGas"], 16),
            int(tx["maxFeePerGas"], 16),
            int(tx["gas"], 16),
            HexBytes(tx["to"]),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            [HexBytes(address) for address in tx["accessList"]],
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
            HexBytes(tx["from"]),
            int(tx["type"], 16),
            int(tx["blockNumber"], 16),
        )
    else:
        # EIP-4844 tx
        return Eip4844(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["maxPriorityFeePerGas"], 16),
            int(tx["maxFeePerGas"], 16),
            int(tx["gas"], 16),
            HexBytes(tx["to"]),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            [HexBytes(address) for address in tx["accessList"]],
            int(tx["maxFeePerBlobGas"], 16),
            [HexBytes(hash32) for hash32 in tx["blobVersionedHashes"]],
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
            HexBytes(tx["from"]),
            int(tx["type"], 16),
            int(tx["blockNumber"], 16),
        )
