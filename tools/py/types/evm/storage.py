from hexbytes import HexBytes
from rlp import decode
from rlp.sedes import Binary, binary
from typing import List, Tuple, Union

from tools.py.utils import little_8_bytes_chunks_to_bytes


class Storage:
    def __init__(self, value: bytes):
        self._value = value

    @property
    def value(self) -> HexBytes:
        return HexBytes(self._value)

    @classmethod
    def from_rpc_data(cls, value: HexBytes) -> "Storage":
        return cls(value)

    @classmethod
    def from_rlp(cls, data: bytes) -> "Storage":
        decoded = decode(data, binary)
        return cls(decoded)


class FeltStorage:
    def __init__(self, storage: Storage):
        self.storage = storage

    def _split_to_felt(self, value: Union[int, bytes, HexBytes]) -> Tuple[int, int]:
        if isinstance(value, (bytes, HexBytes)):
            value = int.from_bytes(value, "big")
        return (value & ((1 << 128) - 1), value >> 128)

    @property
    def value(self) -> Tuple[int, int]:
        return self._split_to_felt(int.from_bytes(self.storage.value, "big"))

    @classmethod
    def from_rlp_chunks(cls, value: HexBytes) -> "FeltStorage":
        return cls(Storage(value))

    @classmethod
    def from_rpc_data(cls, data) -> "FeltStorage":
        return cls(Storage.from_rpc_data(data))

    @classmethod
    def from_rlp_chunks(cls, rlp_chunks: List[int], rlp_len: int) -> "FeltStorage":
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(Storage.from_rlp(rlp))
