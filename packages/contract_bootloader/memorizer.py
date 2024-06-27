from enum import Enum
from marshmallow import fields
from typing import List, Union
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.relocatable import RelocatableValue
from contract_bootloader.memorizer.account_memorizer import (
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.memorizer.header_memorizer import (
    MemorizerKey as HeaderMemorizerKey,
)
from starkware.starkware_utils.marshmallow_dataclass_fields import additional_metadata


class MemorizerId(Enum):
    Header = 0
    Account = 1

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


class Memorizer:
    def __init__(self, dict_values: List[int], list_values: List[int]):
        self.dict = RelocatableValue.from_tuple(dict_values)
        self.list = RelocatableValue.from_tuple(list_values)

    @classmethod
    def from_int(cls, values: List[int]):
        if len(values) != cls.size():
            raise ValueError(
                "Memorizer must be initialized with a list of four integers"
            )
        return cls(values[:2], values[2:])

    @classmethod
    def size(cls) -> int:
        return 2 + 2


@dataclass(frozen=True)
class MemorizerKeyUnion:
    key: Union[HeaderMemorizerKey, AccountMemorizerKey] = fields.Field(
        metadata=additional_metadata(marshmallow_field=fields.Raw())
    )
