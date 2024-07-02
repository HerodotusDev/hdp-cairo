from web3 import Web3
from hexbytes.main import HexBytes
from rlp import Serializable, encode
from rlp.sedes import big_endian_int, Binary, binary

trie_root = Binary.fixed_length(32)


class Account(Serializable):
    fields = (
        ("nonce", big_endian_int),
        ("balance", big_endian_int),
        ("storageRoot", trie_root),
        ("codeHash", binary),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        return encode(self)
