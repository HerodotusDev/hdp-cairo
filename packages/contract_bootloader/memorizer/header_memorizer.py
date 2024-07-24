from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.memorizer import Memorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class MemorizerFunctionId(Enum):
    GET_PARENT = 0
    GET_UNCLE = 1
    GET_COINBASE = 2
    GET_STATE_ROOT = 3
    GET_TRANSACTION_ROOT = 4
    GET_RECEIPT_ROOT = 5
    GET_BLOOM = 6
    GET_DIFFICULTY = 7
    GET_NUMBER = 8
    GET_GAS_LIMIT = 9
    GET_GAS_USED = 10
    GET_TIMESTAMP = 11
    GET_EXTRA_DATA = 12
    GET_MIX_HASH = 13
    GET_NONCE = 14
    GET_BASE_FEE_PER_GAS = 15
    GET_WITHDRAWALS_ROOT = 16
    GET_BLOB_GAS_USED = 17
    GET_EXCESS_BLOB_GAS = 18
    GET_PARENT_BEACON_BLOCK_ROOT = 19

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
            "chain_id": self.chain_id,
            "block_number": self.block_number,
        }

    @classmethod
    def size(cls) -> int:
        return 2


class AbstractHeaderMemorizerBase(ABC):
    def __init__(self, memorizer: Memorizer):
        self.memorizer = memorizer
        self.function_map = {
            MemorizerFunctionId.GET_PARENT: self.get_parent,
            MemorizerFunctionId.GET_UNCLE: self.get_uncle,
            MemorizerFunctionId.GET_COINBASE: self.get_coinbase,
            MemorizerFunctionId.GET_STATE_ROOT: self.get_state_root,
            MemorizerFunctionId.GET_TRANSACTION_ROOT: self.get_transaction_root,
            MemorizerFunctionId.GET_RECEIPT_ROOT: self.get_receipt_root,
            MemorizerFunctionId.GET_BLOOM: self.get_bloom,
            MemorizerFunctionId.GET_DIFFICULTY: self.get_difficulty,
            MemorizerFunctionId.GET_NUMBER: self.get_number,
            MemorizerFunctionId.GET_GAS_LIMIT: self.get_gas_limit,
            MemorizerFunctionId.GET_GAS_USED: self.get_gas_used,
            MemorizerFunctionId.GET_TIMESTAMP: self.get_timestamp,
            MemorizerFunctionId.GET_EXTRA_DATA: self.get_extra_data,
            MemorizerFunctionId.GET_MIX_HASH: self.get_mix_hash,
            MemorizerFunctionId.GET_NONCE: self.get_nonce,
            MemorizerFunctionId.GET_BASE_FEE_PER_GAS: self.get_base_fee_per_gas,
            MemorizerFunctionId.GET_WITHDRAWALS_ROOT: self.get_withdrawals_root,
            MemorizerFunctionId.GET_BLOB_GAS_USED: self.get_blob_gas_used,
            MemorizerFunctionId.GET_EXCESS_BLOB_GAS: self.get_excess_blob_gas,
            MemorizerFunctionId.GET_PARENT_BEACON_BLOCK_ROOT: self.get_parent_beacon_block_root,
        }

    def handle(
        self, function_id: MemorizerFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
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
