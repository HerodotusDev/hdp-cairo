from hexbytes.main import HexBytes
from rlp import Serializable, encode, decode
from rlp.sedes import (
    big_endian_int,
    Binary,
    binary,
    CountableList,
    boolean,
)
from tools.py.types.evm.base_felt import BaseFelt
from web3 import Web3
from typing import List, Tuple

from tools.py.utils import little_8_bytes_chunks_to_bytes

int256 = Binary.fixed_length(256, allow_empty=True)
address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)


class LogEntry(Serializable):
    fields = [("address", address), ("topics", CountableList(hash32)), ("data", binary)]


logs_type = CountableList(LogEntry)


class Receipt(Serializable):
    fields = (
        ("status", boolean),
        ("cumulative_gas_used", big_endian_int),
        ("bloom", Binary.fixed_length(256)),  # Change this line
        ("logs", logs_type),
    )

    def __init__(self, status, cumulative_gas_used, bloom, logs, receipt_type=0):
        # Ensure bloom is always a 256-byte value
        if isinstance(bloom, int):
            bloom = bloom.to_bytes(256, "big")
        elif isinstance(bloom, bytes) and len(bloom) != 256:
            bloom = bloom.rjust(256, b"\x00")
        super().__init__(status, cumulative_gas_used, bloom, logs)
        self.receipt_type = receipt_type

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    @property
    def type(self) -> int:
        return self.receipt_type

    def raw_rlp(self) -> bytes:
        # Remove the bloom conversion here, as it's now always bytes
        if self.receipt_type == 0:
            return encode(
                [
                    self.status,
                    self.cumulative_gas_used,
                    self.bloom,
                    self.logs,
                ]
            )
        else:
            return self.receipt_type.to_bytes(1, "big") + encode(
                [
                    self.status,
                    self.cumulative_gas_used,
                    self.bloom,
                    self.logs,
                ]
            )

    @classmethod
    def from_rpc_data(cls, receipt: dict) -> "Receipt":
        logs_list = [
            LogEntry(
                address=HexBytes(entry["address"]),
                topics=[HexBytes(key) for key in entry["topics"]],
                data=HexBytes(entry["data"]),
            )
            for entry in receipt["logs"]
        ]
        tx_type = int(receipt.get("type", "0x0"), 16)

        status = int(receipt.get("status", "0x0"), 16)

        # Ensure logsBloom is always a 256-byte value
        logs_bloom = HexBytes(receipt["logsBloom"]).rjust(256, b"\x00")

        return cls(
            status,
            int(receipt["cumulativeGasUsed"], 16),
            logs_bloom,
            logs_list,
            receipt_type=tx_type,
        )

    @classmethod
    def from_rlp(cls, data: bytes) -> "Receipt":
        if data and data[0] <= 0x7F:
            receipt_type = data[0]
            decoded = decode(data[1:], cls)
        else:
            receipt_type = 0
            decoded = decode(data, cls)
        return cls(*decoded, receipt_type=receipt_type)


class FeltReceipt(BaseFelt):
    def __init__(self, receipt: Receipt):
        self.receipt = receipt

    def status(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(int(self.receipt.status), as_le)

    def cumulative_gas_used(self, as_le: bool = False) -> Tuple[int, int]:
        return self._split_word_to_felt(self.receipt.cumulative_gas_used, as_le)

    # @property
    # def bloom(self) -> Tuple[int, int]:
    #     return self._split_word_to_felt(int.from_bytes(self.receipt.bloom, 'big'))

    # @property
    # def logs(self) -> Tuple[int, int]:
    #     # Since logs is a list, we'll return the length as a tuple
    #     return self._split_word_to_felt(len(self.receipt.logs))

    # @property
    # def receipt_type(self) -> Tuple[int, int]:
    #     return self._split_word_to_felt(self.receipt.receipt_type)

    def hash(self) -> Tuple[int, int]:
        return self._split_word_to_felt(int.from_bytes(self.receipt.hash(), "big"))

    @classmethod
    def from_rlp_chunks(cls, rlp_chunks: List[int], rlp_len: int) -> "FeltReceipt":
        rlp = little_8_bytes_chunks_to_bytes(rlp_chunks, rlp_len)
        return cls(Receipt.from_rlp(rlp))

    @classmethod
    def from_rpc_data(cls, receipt: dict) -> "FeltReceipt":
        return cls(Receipt.from_rpc_data(receipt))
