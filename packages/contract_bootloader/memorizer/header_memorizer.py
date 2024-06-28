from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.memorizer import Memorizer
from marshmallow_dataclass import class_schema, dataclass


class MemorizerFunctionId(Enum):
    GET_PARENT = 0

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

    @classmethod
    def size(cls) -> int:
        return 2


class AbstractAccountMemorizerBase(ABC):
    def __init__(self, memorizer: Memorizer):
        self.memorizer = memorizer

    def handle(
        self, function_id: MemorizerFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id == MemorizerFunctionId.GET_PARENT:
            return self.get_parent(self, key=key)

    @abstractmethod
    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        pass
