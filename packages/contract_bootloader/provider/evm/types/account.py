from web3 import Web3
from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from rlp.sedes import big_endian_int, Binary, binary

trie_root = Binary.fixed_length(32)


class Account(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("balance", big_endian_int),
        ("storageRoot", trie_root),
        ("codeHash", binary),
    )

    @classmethod
    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    @classmethod
    def raw_rlp(self) -> bytes:
        return encode(self)

    @classmethod
    def decode(cls, data: bytes) -> 'Account':
        decoded = decode(data, cls)
        return cls(*decoded)