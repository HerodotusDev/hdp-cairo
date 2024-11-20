from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class StarknetStateFunctionId(Enum):
    GET_BLOCK_NUMBER = 0
    GET_STATE_ROOT = 1
    GET_SEQUENCER_ADDRESS = 2
    GET_BLOCK_TIMESTAMP = 3
    GET_TRANSACTION_COUNT = 4
    GET_TRANSACTION_COMMITMENT = 5
    GET_EVENT_COUNT = 6
    GET_EVENT_COMMITMENT = 7
    GET_PARENT_BLOCK_HASH = 8
    GET_STATE_DIFF_COMMITMENT = 9
    GET_STATE_DIFF_LENGTH = 10
    GET_L1_GAS_PRICE_IN_WEI = 11
    GET_L1_GAS_PRICE_IN_FRI = 12
    GET_L1_DATA_GAS_PRICE_IN_WEI = 13
    GET_L1_DATA_GAS_PRICE_IN_FRI = 14
    GET_RECEIPTS_COMMITMENT = 15
    GET_L1_DATA_MODE = 16
    GET_PROTOCOL_VERSION = 17

    @classmethod
    def from_int(cls, value: int):
        if not isinstance(value, int):
            raise ValueError(f"Value must be an integer, got {type(value)}")
        for member in cls:
            if member.value == value:
                return member
        raise ValueError(f"{value} is not a valid {cls.__name__}")


@dataclass(frozen=True)
class MemorizerKey:
    chain_id: int
    block_number: int

    @classmethod
    def from_int(cls, values: List[int]):
        if len(values) != cls.size():
            raise ValueError(
                "MemorizerKey must be initialized with a list of two integers"
            )
        return cls(values[0], values[1])

    def derive(self) -> int:
        return poseidon_hash_many([self.chain_id, self.block_number])

    def to_dict(self):
        return {
            "chain_id": hex(self.chain_id),
            "block_number": self.block_number,
        }

    @classmethod
    def size(cls) -> int:
        return 2


class AbstractStarknetHeaderBase(ABC):
    def __init__(self, memorizer: StarknetMemorizer):
        self.memorizer = memorizer
        self.function_map = {
            StarknetStateFunctionId.GET_BLOCK_NUMBER: self.get_block_number,
            StarknetStateFunctionId.GET_STATE_ROOT: self.get_state_root,
            StarknetStateFunctionId.GET_SEQUENCER_ADDRESS: self.get_sequencer_address,
            StarknetStateFunctionId.GET_BLOCK_TIMESTAMP: self.get_block_timestamp,
            StarknetStateFunctionId.GET_TRANSACTION_COUNT: self.get_transaction_count,
            StarknetStateFunctionId.GET_TRANSACTION_COMMITMENT: self.get_transaction_commitment,
            StarknetStateFunctionId.GET_EVENT_COUNT: self.get_event_count,
            StarknetStateFunctionId.GET_EVENT_COMMITMENT: self.get_event_commitment,
            StarknetStateFunctionId.GET_PARENT_BLOCK_HASH: self.get_parent_block_hash,
            StarknetStateFunctionId.GET_STATE_DIFF_COMMITMENT: self.get_state_diff_commitment,
            StarknetStateFunctionId.GET_STATE_DIFF_LENGTH: self.get_state_diff_length,
            StarknetStateFunctionId.GET_L1_GAS_PRICE_IN_WEI: self.get_l1_gas_price_in_wei,
            StarknetStateFunctionId.GET_L1_GAS_PRICE_IN_FRI: self.get_l1_gas_price_in_fri,
            StarknetStateFunctionId.GET_L1_DATA_GAS_PRICE_IN_WEI: self.get_l1_data_gas_price_in_wei,
            StarknetStateFunctionId.GET_L1_DATA_GAS_PRICE_IN_FRI: self.get_l1_data_gas_price_in_fri,
            StarknetStateFunctionId.GET_RECEIPTS_COMMITMENT: self.get_receipts_commitment,
            StarknetStateFunctionId.GET_L1_DATA_MODE: self.get_l1_data_mode,
            StarknetStateFunctionId.GET_PROTOCOL_VERSION: self.get_protocol_version,
        }

    def handle(
        self, function_id: StarknetStateFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_block_number(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_state_root(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_sequencer_address(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_block_timestamp(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_transaction_count(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_transaction_commitment(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_event_count(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_event_commitment(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_parent_block_hash(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_state_diff_commitment(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_state_diff_length(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_l1_gas_price_in_wei(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_l1_gas_price_in_fri(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_l1_data_gas_price_in_wei(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_l1_data_gas_price_in_fri(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_receipts_commitment(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_l1_data_mode(self, key: MemorizerKey) -> int:
        pass

    @abstractmethod
    def get_protocol_version(self, key: MemorizerKey) -> int:
        pass

    def _get_felt_range(self, start_addr: int, end_addr: int) -> List[int]:
        assert isinstance(start_addr, RelocatableValue)
        assert isinstance(end_addr, RelocatableValue)
        assert start_addr.segment_index == end_addr.segment_index, (
            "Inconsistent start and end segment indices "
            f"({start_addr.segment_index} != {end_addr.segment_index})."
        )

        assert start_addr.offset <= end_addr.offset, (
            "The start offset cannot be greater than the end offset"
            f"({start_addr.offset} > {end_addr.offset})."
        )

        size = end_addr.offset - start_addr.offset
        return self.segments.memory.get_range_as_ints(addr=start_addr, size=size)
