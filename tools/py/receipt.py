from hexbytes.main import HexBytes
from rlp import Serializable, encode
from rlp.sedes import (
    BigEndianInt,
    big_endian_int,
    Binary,
    binary,
    CountableList,
    boolean,
)
from web3 import Web3

int256 = Binary.fixed_length(256, allow_empty=True)
address = Binary.fixed_length(20, allow_empty=True)
hash32 = Binary.fixed_length(32)


class LogEntry(Serializable):
    fields = [("address", address), ("topics", CountableList(hash32)), ("data", binary)]


logs_type = CountableList(LogEntry)


class Receipt(Serializable):
    fields = (
        ("success", boolean),
        ("cumulative_gas_used", big_endian_int),
        ("bloom", int256),
        ("logs", logs_type),
        ("type", big_endian_int),
        ("block_number", big_endian_int),
    )

    def hash(self) -> HexBytes:
        return Web3.keccak(self.raw_rlp())

    def raw_rlp(self) -> bytes:
        if self.bloom > 0:
            bloom = self.bloom.to_bytes(256, "big")
        else:
            bloom = self.bloom
        if self.type == 0:
            return encode(
                [
                    self.success,
                    self.cumulative_gas_used,
                    bloom,
                    self.logs,
                ]
            )
        else:
            return self.type.to_bytes(1, "big") + encode(
                [
                    self.success,
                    self.cumulative_gas_used,
                    bloom,
                    self.logs,
                ]
            )


def build_receipt(receipt):
    logs_list = [
        LogEntry(
            address=HexBytes(entry["address"]),
            topics=[HexBytes(key) for key in entry["topics"]],
            data=HexBytes(entry["data"]),
        )
        for entry in receipt["logs"]
    ]
    tx_type = "0x0" if "type" not in receipt else receipt["type"]

    status = "0x0" if "status" not in receipt else receipt["status"]

    return Receipt(
        int(status, 16),
        int(receipt["cumulativeGasUsed"], 16),
        int.from_bytes(HexBytes(receipt["logsBloom"]), "big"),
        logs_list,
        int(tx_type, 16),
        int(receipt["blockNumber"], 16),
    )
