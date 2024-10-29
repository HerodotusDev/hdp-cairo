from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from tools.py.types.evm.base_felt import BaseFelt
from web3.types import TxParams
from rlp.sedes import BigEndianInt, big_endian_int, Binary, binary, lists, CountableList
from web3 import Web3
from typing import Union, List, Tuple
from eth_keys import keys
from contract_bootloader.memorizer.evm.block_tx import (
    MemorizerKey as BlockTxMemorizerKey,
)

from tools.py.utils import little_8_bytes_chunks_to_bytes

address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)
int256 = BigEndianInt(256)
trie_root = Binary.fixed_length(32, allow_empty=True)


class LegacyTx(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("receiver", address),
        ("value", big_endian_int),
        ("data", binary),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def get_signing_hash(self) -> bytes:
        rlp = encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
            ]
        )
        return Web3.keccak(rlp)

    def derive_sender(self) -> bytes:
        sig = keys.Signature(signature_bytes=self.r + self.s + bytes([self.v - 27]))
        address_str = sig.recover_public_key_from_msg_hash(
            self.get_signing_hash()
        ).to_address()
        return bytes.fromhex(address_str[2:])  # Remove '0x' prefix and convert to bytes

    def raw_rlp(self) -> bytes:
        return encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.v,
                self.r,
                self.s,
            ]
        )

    @classmethod
    def from_rlp(cls, _chain_id: int, data: bytes) -> "LegacyTx":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, _chain_id: int, tx: TxParams) -> "LegacyTx":
        receiver = "" if tx["to"] is None else tx["to"]
        return cls(
            int(tx["nonce"], 16),
            int(tx["gasPrice"], 16),
            int(tx["gas"], 16),
            HexBytes(receiver),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
        )


class Eip155(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("receiver", address),
        ("value", big_endian_int),
        ("data", binary),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
    )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.chain_id = None

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.v,
                self.r,
                self.s,
            ]
        )

    def get_signing_hash(self) -> bytes:
        rlp = encode(
            [
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.chain_id,
                0,
                0,
            ]
        )
        return Web3.keccak(rlp)

    def derive_sender(self) -> bytes:
        v = self.v - self.chain_id * 2 - 35

        r = int.from_bytes(self.r, "big")
        s = int.from_bytes(self.s, "big")

        sig = keys.Signature(vrs=(v, r, s))
        address_str = sig.recover_public_key_from_msg_hash(
            self.get_signing_hash()
        ).to_address()
        return bytes.fromhex(address_str[2:])  # Remove '0x' prefix and convert to bytes

    @classmethod
    def from_rlp(cls, chain_id: int, data: bytes) -> "Eip155":
        instance = decode(data, cls)
        instance.chain_id = chain_id
        return instance

    @classmethod
    def from_rpc_data(cls, chain_id: int, tx: TxParams) -> "Eip155":
        receiver = "" if tx["to"] is None else tx["to"]
        instance = cls(
            int(tx["nonce"], 16),
            int(tx["gasPrice"], 16),
            int(tx["gas"], 16),
            HexBytes(receiver),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
        )
        instance.chain_id = chain_id
        return instance


# Define a Serializable class for an Access List entry
class AccessListEntry(Serializable):
    fields = [("address", address), ("storage_keys", CountableList(hash32))]


# Define the access list using CountableList of AccessListEntry
access_list_type = CountableList(AccessListEntry)


class Eip2930(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("gas_price", big_endian_int),
        ("gas_limit", big_endian_int),
        ("receiver", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", access_list_type),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
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
                self.receiver,
                self.value,
                self.data,
                self.access_list,
                self.v,
                self.r,
                self.s,
            ]
        )

    @classmethod  # The RLP passed here should be the unpacked TX envelope
    def from_rlp(cls, _chain_id: int, data: bytes) -> "Eip2930":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, _chain_id: int, tx: TxParams) -> "Eip2930":
        receiver = "" if tx["to"] is None else tx["to"]
        access_list = [
            AccessListEntry(
                address=HexBytes(entry["address"]),
                storage_keys=[HexBytes(key) for key in entry["storageKeys"]],
            )
            for entry in tx["accessList"]
        ]

        return Eip2930(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["gasPrice"], 16),
            int(tx["gas"], 16),
            HexBytes(receiver),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            access_list,
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
        )

    def get_signing_hash(self) -> bytes:
        rlp = encode(
            [
                self.chain_id,
                self.nonce,
                self.gas_price,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.access_list,
            ]
        )
        return Web3.keccak(bytes.fromhex("01") + rlp)

    def derive_sender(self) -> bytes:
        v = self.v
        r = int.from_bytes(self.r, "big")
        s = int.from_bytes(self.s, "big")

        sig = keys.Signature(vrs=(v, r, s))
        address_str = sig.recover_public_key_from_msg_hash(
            self.get_signing_hash()
        ).to_address()
        return bytes.fromhex(address_str[2:])  # Remove '0x' prefix and convert to bytes


class Eip1559(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("max_priority_fee_per_gas", big_endian_int),
        ("max_fee_per_gas", big_endian_int),
        ("gas_limit", big_endian_int),
        ("receiver", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", access_list_type),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
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
                self.receiver,
                self.value,
                self.data,
                self.access_list,
                self.v,
                self.r,
                self.s,
            ]
        )

    @classmethod
    def from_rlp(cls, _chain_id: int, data: bytes) -> "Eip1559":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, _chain_id: int, tx: TxParams) -> "Eip1559":
        receiver = "" if tx["to"] is None else tx["to"]
        access_list = [
            AccessListEntry(
                address=HexBytes(entry["address"]),
                storage_keys=[HexBytes(key) for key in entry["storageKeys"]],
            )
            for entry in tx["accessList"]
        ]
        # EIP-1559 tx
        return Eip1559(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["maxPriorityFeePerGas"], 16),
            int(tx["maxFeePerGas"], 16),
            int(tx["gas"], 16),
            HexBytes(receiver),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            access_list,
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
        )

    def get_signing_hash(self) -> bytes:
        rlp = encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.access_list,
            ]
        )
        return Web3.keccak(bytes.fromhex("02") + rlp)

    def derive_sender(self) -> bytes:
        v = self.v
        r = int.from_bytes(self.r, "big")
        s = int.from_bytes(self.s, "big")

        sig = keys.Signature(vrs=(v, r, s))
        address_str = sig.recover_public_key_from_msg_hash(
            self.get_signing_hash()
        ).to_address()
        return bytes.fromhex(address_str[2:])


class Eip4844(Serializable):
    fields = (
        ("chain_id", big_endian_int),
        ("nonce", big_endian_int),
        ("max_priority_fee_per_gas", big_endian_int),
        ("max_fee_per_gas", big_endian_int),
        ("gas_limit", big_endian_int),
        ("receiver", address),
        ("value", big_endian_int),
        ("data", binary),
        ("access_list", access_list_type),
        ("max_fee_per_blob_gas", big_endian_int),
        ("blob_versioned_hashes", lists.CountableList(hash32)),
        ("v", big_endian_int),
        ("r", hash32),
        ("s", hash32),
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
                self.receiver,
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

    @classmethod
    def from_rlp(cls, _chain_id: int, data: bytes) -> "Eip4844":
        return decode(data, cls)

    @classmethod
    def from_rpc_data(cls, _chain_id: int, tx: TxParams) -> "Eip4844":
        receiver = "" if tx["to"] is None else tx["to"]
        access_list = [
            AccessListEntry(
                address=HexBytes(entry["address"]),
                storage_keys=[HexBytes(key) for key in entry["storageKeys"]],
            )
            for entry in tx["accessList"]
        ]
        return Eip4844(
            int(tx["chainId"], 16),
            int(tx["nonce"], 16),
            int(tx["maxPriorityFeePerGas"], 16),
            int(tx["maxFeePerGas"], 16),
            int(tx["gas"], 16),
            HexBytes(receiver),
            int(tx["value"], 16),
            HexBytes(tx["input"]),
            access_list,
            int(tx["maxFeePerBlobGas"], 16),
            [HexBytes(hash32) for hash32 in tx["blobVersionedHashes"]],
            int(tx["v"], 16),
            HexBytes(tx["r"]),
            HexBytes(tx["s"]),
        )

    def get_signing_hash(self) -> bytes:
        rlp = encode(
            [
                self.chain_id,
                self.nonce,
                self.max_priority_fee_per_gas,
                self.max_fee_per_gas,
                self.gas_limit,
                self.receiver,
                self.value,
                self.data,
                self.access_list,
                self.max_fee_per_blob_gas,
                self.blob_versioned_hashes,
            ]
        )
        return Web3.keccak(bytes.fromhex("03") + rlp)

    def derive_sender(self) -> bytes:
        v = self.v
        r = int.from_bytes(self.r, "big")
        s = int.from_bytes(self.s, "big")

        sig = keys.Signature(vrs=(v, r, s))
        address_str = sig.recover_public_key_from_msg_hash(
            self.get_signing_hash()
        ).to_address()
        return bytes.fromhex(address_str[2:])


class Tx:
    def __init__(self):
        self.tx: Union[LegacyTx, Eip155, Eip2930, Eip1559, Eip4844] = None

    @property
    def hash(self) -> HexBytes:
        return self.tx.hash()

    @property
    def nonce(self) -> int:
        return self.tx.nonce

    @property
    def gas_price(self) -> int:
        if isinstance(self.tx, (LegacyTx, Eip155, Eip2930)):
            return self.tx.gas_price
        raise AttributeError("gas_price is not available for this transaction type")

    @property
    def gas_limit(self) -> int:
        return self.tx.gas_limit

    @property
    def receiver(self) -> Union[bytes, str]:
        return self.tx.receiver

    @property
    def value(self) -> int:
        return self.tx.value

    @property
    def data(self) -> bytes:
        return self.tx.data

    @property
    def v(self) -> int:
        return self.tx.v

    @property
    def r(self) -> HexBytes:
        return self.tx.r

    @property
    def s(self) -> HexBytes:
        return self.tx.s

    @property
    def chain_id(self) -> int:
        if isinstance(self.tx, (Eip2930, Eip1559, Eip4844)):
            return self.tx.chain_id
        raise AttributeError("chain_id is not available for this transaction type")

    @property
    def access_list(self) -> List[AccessListEntry]:
        if isinstance(self.tx, (Eip2930, Eip1559, Eip4844)):
            return self.tx.access_list
        raise AttributeError("access_list is not available for this transaction type")

    @property
    def max_priority_fee_per_gas(self) -> int:
        if isinstance(self.tx, (Eip1559, Eip4844)):
            return self.tx.max_priority_fee_per_gas
        raise AttributeError(
            "max_priority_fee_per_gas is not available for this transaction type"
        )

    @property
    def max_fee_per_gas(self) -> int:
        if isinstance(self.tx, (Eip1559, Eip4844)):
            return self.tx.max_fee_per_gas
        raise AttributeError(
            "max_fee_per_gas is not available for this transaction type"
        )

    @property
    def max_fee_per_blob_gas(self) -> int:
        if isinstance(self.tx, Eip4844):
            return self.tx.max_fee_per_blob_gas
        raise AttributeError(
            "max_fee_per_blob_gas is not available for this transaction type"
        )

    @property
    def blob_versioned_hashes(self) -> List[HexBytes]:
        if isinstance(self.tx, Eip4844):
            return self.tx.blob_versioned_hashes
        raise AttributeError(
            "blob_versioned_hashes is not available for this transaction type"
        )

    @property
    def type(self) -> int:
        if isinstance(self.tx, LegacyTx):
            return 0
        elif isinstance(self.tx, Eip155):
            return 0
        elif isinstance(self.tx, Eip2930):
            return 1
        elif isinstance(self.tx, Eip1559):
            return 2
        elif isinstance(self.tx, Eip4844):
            return 3

    @property
    def sender(self) -> bytes:
        return self.tx.derive_sender()

    def raw_rlp(self) -> bytes:
        return self.tx.raw_rlp()

    @classmethod
    def from_rpc_data(cls, chain_id: int, tx: TxParams) -> "Tx":
        instance = cls()
        tx_type = "0x0" if "type" not in tx else tx["type"]
        if tx_type == "0x0":
            if int(tx["v"], 16) >= 35:  # EIP-155 can be detected by v >= 35
                instance.tx = Eip155.from_rpc_data(chain_id, tx)
            else:
                instance.tx = LegacyTx.from_rpc_data(chain_id, tx)
        elif tx_type == "0x1":
            instance.tx = Eip2930.from_rpc_data(chain_id, tx)
        elif tx_type == "0x2":
            instance.tx = Eip1559.from_rpc_data(chain_id, tx)
        elif tx_type == "0x3":
            instance.tx = Eip4844.from_rpc_data(chain_id, tx)
        else:
            raise ValueError(f"Unknown transaction type: {tx_type}")
        return instance

    @classmethod
    def from_rlp(cls, chain_id: int, data: bytes) -> "Tx":
        instance = cls()
        if data[0] > 0x7F:
            # Legacy transaction (no envelope)
            decoded_tx = decode(data)
            if (
                int.from_bytes(decoded_tx[6], "big") >= 35
            ):  # EIP-155 can be detected by v >= 35
                instance.tx = Eip155.from_rlp(chain_id, data)
            else:
                instance.tx = LegacyTx.from_rlp(chain_id, data)
        else:
            # EIP-2718 transaction envelope
            tx_type = data[0]
            tx_payload = data[1:]

            if tx_type == 0x01:
                instance.tx = Eip2930.from_rlp(chain_id, tx_payload)
            elif tx_type == 0x02:
                instance.tx = Eip1559.from_rlp(chain_id, tx_payload)
            elif tx_type == 0x03:
                instance.tx = Eip4844.from_rlp(chain_id, tx_payload)
            else:
                raise ValueError(f"Unknown transaction type: {tx_type}")

        return instance


class FeltTx(BaseFelt):
    def __init__(self, tx: Tx):
        self.tx = tx

    def hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.hash, as_le)

    def nonce(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.nonce, as_le)

    def gas_price(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.gas_price, as_le)

    def gas_limit(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.gas_limit, as_le)

    def receiver(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(int.from_bytes(self.tx.receiver, "big"))

    def value(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.value, as_le)

    # def data(self, as_le: bool = False) -> Tuple[int, int]:
    #     return self._split_word_to_felt(int.from_bytes(self.tx.data, 'big'), as_le)

    def v(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.v, as_le)

    def r(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(int.from_bytes(self.tx.r, "big"), as_le)

    def s(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(int.from_bytes(self.tx.s, "big"), as_le)

    def chain_id(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.chain_id, as_le)

    # def access_list(self, as_le: bool = False) -> Tuple[int, int]:
    #     return self._split_word_to_felt(len(self.tx.access_list), as_le)

    def max_priority_fee_per_gas(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.max_priority_fee_per_gas, as_le)

    def max_fee_per_gas(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.max_fee_per_gas, as_le)

    def max_fee_per_blob_gas(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.max_fee_per_blob_gas, as_le)

    # def blob_versioned_hashes(self, as_le: bool = False) -> Tuple[int, int]:
    #     return self._split_word_to_felt(len(self.tx.blob_versioned_hashes), as_le)

    def type(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.type, as_le)

    def sender(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.tx.sender, as_le)

    @classmethod
    def from_rlp_chunks(
        cls, key: BlockTxMemorizerKey, rlp_chunks: List[int], rlp_len: int
    ) -> "FeltTx":
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(Tx.from_rlp(key.chain_id, rlp))

    @classmethod
    def from_rpc_data(cls, key: BlockTxMemorizerKey, data) -> "FeltTx":
        return cls(Tx.from_rpc_data(key.chain_id, data))
