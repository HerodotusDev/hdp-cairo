from web3 import Web3
from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.memorizer import Memorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class MemorizerFunctionId(Enum):
    GET_NONCE = 0
    GET_BALANCE = 1
    GET_STATE_ROOT = 2
    GET_CODE_HASH = 3

    @classmethod
    def from_int(cls, value: int):
        if not isinstance(value, int):
            raise ValueError(f"Value must be an integer, got {type(value)}")
        for member in cls:
            if member.value == value:
                return member
        raise ValueError(f"{value} is not a valid {cls.__name__}")

    @classmethod
    def size(cls) -> int:
        return 1


@dataclass(frozen=True)
class MemorizerKey:
    chain_id: int
    block_number: int
    address: int

    @classmethod
    def from_int(cls, values: List[int]):
        if len(values) != cls.size():
            raise ValueError(
                "MemorizerKey must be initialized with a list of three integers"
            )
        return cls(values[0], values[1], values[2])

    def derive(self) -> int:
        return poseidon_hash_many([self.chain_id, self.block_number, self.address])

    def to_dict(self):
        return {
            "chain_id": self.chain_id,
            "block_number": self.block_number,
            "address": Web3.toChecksumAddress(f"0x{self.address:040x}"),
        }

    @classmethod
    def size(cls) -> int:
        return 3


class AbstractAccountMemorizerBase(ABC):
    def __init__(self, memorizer: Memorizer):
        self.memorizer = memorizer
        self.function_map = {
            MemorizerFunctionId.GET_NONCE: self.get_nonce,
            MemorizerFunctionId.GET_BALANCE: self.get_balance,
            MemorizerFunctionId.GET_STATE_ROOT: self.get_state_root,
            MemorizerFunctionId.GET_CODE_HASH: self.get_code_hash,
        }

    def handle(
        self, function_id: MemorizerFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_balance(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_code_hash(self, key: MemorizerKey) -> Tuple[int, int]:
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
