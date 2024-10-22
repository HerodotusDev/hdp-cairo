from web3 import Web3
from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from rlp.sedes import big_endian_int, Binary
from typing import List, Tuple, Union

from tools.py.types.evm.base_felt import BaseFelt
from tools.py.utils import little_8_bytes_chunks_to_bytes

hash32 = Binary.fixed_length(32)


class Account(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("balance", big_endian_int),
        ("storageHash", hash32),
        ("codeHash", hash32),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def from_rlp(cls, data: bytes) -> "Account":
        decoded = decode(data, cls)
        return cls(*decoded)

    @classmethod
    def from_rpc_data(cls, data) -> "Account":
        return cls(
            int.from_bytes(HexBytes(data["nonce"]), "big"),
            int.from_bytes(HexBytes(data["balance"]), "big"),
            HexBytes(data["storageHash"]),
            HexBytes(data["codeHash"]),
        )


class FeltAccount(BaseFelt):
    def __init__(self, account: Account):
        self.account = account

    def nonce(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.account.nonce, as_le)

    def balance(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.account.balance, as_le)

    def storage_hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(
            int.from_bytes(self.account.storageHash, "big"), as_le
        )

    def code_hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(
            int.from_bytes(self.account.codeHash, "big"), as_le
        )

    def hash(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(
            int.from_bytes(self.account.hash(), "big"), as_le
        )

    @classmethod
    def from_rlp_chunks(cls, rlp_chunks: List[int], rlp_len: int) -> "FeltAccount":
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(Account.from_rlp(rlp))

    @classmethod
    def from_rpc_data(cls, data) -> "FeltAccount":
        return cls(Account.from_rpc_data(data))
