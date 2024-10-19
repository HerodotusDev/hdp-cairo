from web3 import Web3
from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from rlp.sedes import big_endian_int, Binary
from typing import List, Tuple, Union

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
    def from_rlp(cls, data: bytes) -> 'Account':
        decoded = decode(data, cls)
        return cls(*decoded)
    
    @classmethod
    def from_rpc_data(cls, data) -> 'Account':
        return cls(
            int.from_bytes(HexBytes(data["nonce"]), "big"),
            int.from_bytes(HexBytes(data["balance"]), "big"),
            HexBytes(data["storageHash"]),
            HexBytes(data["codeHash"]),
        )

class FeltAccount:
    def __init__(self, account: Account):
        self.account = account

    def _split_to_felt(self, value: Union[int, bytes, HexBytes]) -> Tuple[int, int]:
        if isinstance(value, (bytes, HexBytes)):
            value = int.from_bytes(value, 'big')
        return (value & ((1 << 128) - 1), value >> 128)

    @property
    def nonce(self) -> Tuple[int, int]:
        return self._split_to_felt(self.account.nonce)

    @property
    def balance(self) -> Tuple[int, int]:
        return self._split_to_felt(self.account.balance)

    @property
    def storage_hash(self) -> Tuple[int, int]:
        return self._split_to_felt(int.from_bytes(self.account.storageHash, 'big'))

    @property
    def code_hash(self) -> Tuple[int, int]:
        return self._split_to_felt(int.from_bytes(self.account.codeHash, 'big'))

    def hash(self) -> Tuple[int, int]:
        return self._split_to_felt(int.from_bytes(self.account.hash(), 'big'))
    
    @classmethod
    def from_rlp_chunks(cls, rlp_chunks: List[int], rlp_len: int) -> 'FeltAccount':
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(Account.from_rlp(rlp))
