from enum import Enum
from typing import List
from starkware.cairo.common.dict import DictManager
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class MemorizerId(Enum):
    Header = 0
    Account = 1
    Storage = 2

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
    def __init__(self, dict_raw_ptrs: List[int], dict_manager: DictManager):
        if len(dict_raw_ptrs) != self.size():
            raise ValueError(
                "Memorizer must be initialized with a list of two integers"
            )
        self.dict_ptr = RelocatableValue.from_tuple(dict_raw_ptrs)
        self.dict_manager = dict_manager

    @classmethod
    def size(cls) -> int:
        return 2

    def read(self, key: int) -> int:
        return self.dict_manager.get_dict(self.dict_ptr)[key]
