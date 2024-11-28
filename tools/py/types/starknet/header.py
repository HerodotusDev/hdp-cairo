from dataclasses import dataclass
from typing import Union

from tools.py.utils import compute_hash_on_elements
from poseidon_py.poseidon_hash import (
    poseidon_hash_many,
)


@dataclass(slots=True, frozen=True)
class LegacyStarknetBlock:
    """
    Starknet block data class.
    Reference : https://docs.starknet.io/documentation/architecture_and_concepts/Network_Architecture/header/
    Compatible with 0.12 <= Starknet version <= 0.13.1.
    """

    block_number: int  # The number, that is, the height, of this block.
    state_root: int  # The state commitment after the block.
    sequencer_address: (
        int  # The Starknet address of the sequencer that created the block
    )
    block_timestamp: int  # The time at which the sequencer began building the block, in seconds since the Unix epoch.
    transaction_count: int  # The number of transactions in the block.
    transaction_commitment: int  # A commitment to the transactions included in the block. The root of a height-64 binary Merkle Patricia trie. The leaf at index i corresponds to h(transaction_hash, signature)
    event_count: int  # The number of events in the block.
    event_commitment: int  # A commitment to the events produced in the block. The root of a height-64 binary Merkle Patricia trie. The leaf at index i corresponds to the hash of the i-th event.
    parent_block_hash: int  # The hash of the block’s parent.

    def hash(self):
        """
        Ref : https://docs.starknet.io/documentation/architecture_and_concepts/Network_Architecture/header/#block_hash

        Note : Works only for 0.7 < Starknet < 0.13.2 .
        """
        fields = self.to_fields()
        return compute_hash_on_elements(fields)

    def to_fields(self) -> list[int]:
        return [
            self.block_number,
            self.state_root,
            self.sequencer_address,
            self.block_timestamp,
            self.transaction_count,
            self.transaction_commitment,
            self.event_count,
            self.event_commitment,
            0,
            0,
            self.parent_block_hash,
        ]


@dataclass(slots=True, frozen=True)
class StarknetBlockV0_13_2(LegacyStarknetBlock):
    """
    Represents a Starknet block for version 0.13.2.
    Key changes include new fields and swithcing to poseidon.
    """

    state_diff_commitment: int
    state_diff_length: int
    receipt_commitment: int
    protocol_version: str
    l1_gas_price_wei: int  # The price of L1 gas that was used while constructing the block. The first Integer value is the price in wei. The second is the price in fri.
    l1_gas_price_fri: int
    l1_data_gas_price_wei: int  # The price of L1 blob gas that was used while constructing the block. If the l1_DA_MODE of the block is set to BLOB, L1 blob gas prices determines the storage update cost. The first Integer value is the price in wei. The second is the price in fri.
    l1_data_gas_price_fri: int
    l1_da_mode: str

    def concat_counts(self) -> int:
        concat_counts = bytearray(32)
        # Write transaction_count
        concat_counts[0:8] = self.transaction_count.to_bytes(8, byteorder="big")

        # Write event_count
        concat_counts[8:16] = self.event_count.to_bytes(8, byteorder="big")

        # Write state_diff_length
        concat_counts[16:24] = self.state_diff_length.to_bytes(8, byteorder="big")

        # Write l1_da_mode
        l1_da_mode_byte = 0b10000000 if self.l1_da_mode == "BLOB" else 0
        concat_counts[24] = l1_da_mode_byte

        concat_counts_int = int.from_bytes(concat_counts, byteorder="big")
        return concat_counts_int

    def hash(self):
        """
        Ref: https://github.com/eqlabs/pathfinder/blob/9e0ceec2c56a88ed58b6e49ee7ca6bccd703af33/crates/pathfinder/src/state/block_hash.rs#L408
        """
        fields = self.to_fields()
        return poseidon_hash_many(fields)

    def to_fields(self) -> list[int]:
        fields = [
            int.from_bytes(b"STARKNET_BLOCK_HASH0", "big"),
            self.block_number,
            self.state_root,
            self.sequencer_address,
            self.block_timestamp,
            self.concat_counts(),
            self.state_diff_commitment,
            self.transaction_commitment,
            self.event_commitment,
            self.receipt_commitment,
            self.l1_gas_price_wei,
            self.l1_gas_price_fri,
            self.l1_data_gas_price_wei,
            self.l1_data_gas_price_fri,
            int.from_bytes(self.protocol_version.encode("ascii"), byteorder="big"),
            0,
            self.parent_block_hash,
        ]
        return fields


class StarknetHeader:
    def __init__(self):
        self.header: Union[LegacyStarknetBlock, StarknetBlockV0_13_2] = None

    @property
    def hash(self) -> int:
        return self.header.hash()

    @property
    def parent_block_hash(self) -> int:
        return self.header.parent_block_hash

    @property
    def block_number(self) -> int:
        return self.header.block_number

    @property
    def state_root(self) -> int:
        return self.header.state_root

    @property
    def sequencer_address(self) -> int:
        return self.header.sequencer_address

    @property
    def block_timestamp(self) -> int:
        return self.header.block_timestamp

    @property
    def transaction_count(self) -> int:
        return self.header.transaction_count

    @property
    def transaction_commitment(self) -> int:
        return self.header.transaction_commitment

    @property
    def event_count(self) -> int:
        return self.header.event_count

    @property
    def event_commitment(self) -> int:
        return self.header.event_commitment

    @property
    def l1_gas_price_wei(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.l1_gas_price_wei
        raise AttributeError("l1_gas_price_wei is not available for this block version")

    @property
    def l1_gas_price_fri(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.l1_gas_price_fri
        raise AttributeError("l1_gas_price_fri is not available for this block version")

    @property
    def l1_data_gas_price_wei(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.l1_data_gas_price_wei
        raise AttributeError(
            "l1_data_gas_price_wei is not available for this block version"
        )

    @property
    def l1_data_gas_price_fri(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.l1_data_gas_price_fri
        raise AttributeError(
            "l1_data_gas_price_fri is not available for this block version"
        )

    @property
    def l1_da_mode(self) -> str:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.l1_da_mode
        raise AttributeError("l1_da_mode is not available for this block version")

    @property
    def protocol_version(self) -> str:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.protocol_version
        raise AttributeError("protocol_version is not available for this block version")

    @property
    def state_diff_commitment(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.state_diff_commitment
        raise AttributeError(
            "state_diff_commitment is not available for this block version"
        )

    @property
    def state_diff_length(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.state_diff_length
        raise AttributeError(
            "state_diff_length is not available for this block version"
        )

    @property
    def receipt_commitment(self) -> int:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return self.header.receipt_commitment
        raise AttributeError(
            "receipt_commitment is not available for this block version"
        )

    @property
    def version(self) -> str:
        if isinstance(self.header, StarknetBlockV0_13_2):
            return "0.13.2"
        raise AttributeError("version is not available for this block version")

    @classmethod
    def from_feeder_data(cls, feeder_header: list[dict]) -> "StarknetHeader":
        instance = cls()
        # Map RPC response fields to block class fields
        block_fields = {
            "parent_block_hash": int(feeder_header["parent_block_hash"], 16),
            "block_number": feeder_header["block_number"],
            "state_root": int(feeder_header["state_root"], 16),
            "sequencer_address": int(feeder_header["sequencer_address"], 16),
            "block_timestamp": feeder_header["timestamp"],
            "transaction_count": len(feeder_header["transactions"]),
            "transaction_commitment": int(feeder_header["transaction_commitment"], 16),
            "event_commitment": int(feeder_header["event_commitment"], 16),
            "event_count": sum(
                len(receipt["events"])
                for receipt in feeder_header["transaction_receipts"]
            ),
        }

        if (
            feeder_header["starknet_version"] == "0.13.2"
            or feeder_header["starknet_version"] == "0.13.2.1"
        ):
            block_fields.update(
                {
                    "l1_gas_price_wei": int(
                        feeder_header["l1_gas_price"]["price_in_wei"], 16
                    ),
                    "l1_gas_price_fri": int(
                        feeder_header["l1_gas_price"]["price_in_fri"], 16
                    ),
                    "l1_data_gas_price_wei": int(
                        feeder_header["l1_data_gas_price"]["price_in_wei"], 16
                    ),
                    "l1_data_gas_price_fri": int(
                        feeder_header["l1_data_gas_price"]["price_in_fri"], 16
                    ),
                    "l1_da_mode": feeder_header["l1_da_mode"],
                    "state_diff_commitment": int(
                        feeder_header["state_diff_commitment"], 16
                    ),
                    "state_diff_length": feeder_header["state_diff_length"],
                    "receipt_commitment": int(feeder_header["receipt_commitment"], 16),
                    "protocol_version": feeder_header["starknet_version"],
                }
            )
            instance.header = StarknetBlockV0_13_2(**block_fields)
        else:
            instance.header = LegacyStarknetBlock(**block_fields)

        return instance

    @classmethod
    def from_memorizer_fields(cls, memorizer_fields: list[int]) -> "StarknetHeader":
        if memorizer_fields[1] == int.from_bytes(b"STARKNET_BLOCK_HASH0", "big"):
            # v2
            # Extract counts from concatenated value
            concat_counts = memorizer_fields[6]
            concat_bytes = concat_counts.to_bytes(32, byteorder="big")

            transaction_count = int.from_bytes(concat_bytes[0:8], byteorder="big")
            event_count = int.from_bytes(concat_bytes[8:16], byteorder="big")
            state_diff_length = int.from_bytes(concat_bytes[16:24], byteorder="big")
            l1_da_mode = "BLOB" if concat_bytes[24] & 0b10000000 else "CALLDATA"

            instance = cls()
            instance.header = StarknetBlockV0_13_2(
                block_number=memorizer_fields[2],
                state_root=memorizer_fields[3],
                sequencer_address=memorizer_fields[4],
                block_timestamp=memorizer_fields[5],
                transaction_count=transaction_count,
                event_count=event_count,
                state_diff_length=state_diff_length,
                l1_da_mode=l1_da_mode,
                state_diff_commitment=memorizer_fields[7],
                transaction_commitment=memorizer_fields[8],
                event_commitment=memorizer_fields[9],
                receipt_commitment=memorizer_fields[10],
                l1_gas_price_wei=memorizer_fields[11],
                l1_gas_price_fri=memorizer_fields[12],
                l1_data_gas_price_wei=memorizer_fields[13],
                l1_data_gas_price_fri=memorizer_fields[14],
                protocol_version=memorizer_fields[15]
                .to_bytes(32, byteorder="big")
                .decode("ascii")
                .rstrip("\x00"),
                parent_block_hash=memorizer_fields[17],
            )
            return instance
        else:
            # Legacy header
            instance = cls()
            instance.header = LegacyStarknetBlock(
                block_number=memorizer_fields[1],
                state_root=memorizer_fields[2],
                sequencer_address=memorizer_fields[3],
                block_timestamp=memorizer_fields[4],
                transaction_count=memorizer_fields[5],
                transaction_commitment=memorizer_fields[6],
                event_count=memorizer_fields[7],
                event_commitment=memorizer_fields[8],
                parent_block_hash=memorizer_fields[11],
            )
            return instance
