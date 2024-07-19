from web3 import Web3
from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.memorizer import Memorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many


class MemorizerFunctionId(Enum):
    GET_BALANCE = 1

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
            "address": Web3.toChecksumAddress(hex(self.address)),
        }

    @classmethod
    def size(cls) -> int:
        return 3


class AbstractAccountMemorizerBase(ABC):
    def __init__(self, memorizer: Memorizer):
        self.memorizer = memorizer

    def handle(
        self, function_id: MemorizerFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id == MemorizerFunctionId.GET_BALANCE:
            return self.get_balance(key=key)

    @abstractmethod
    def get_balance(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
