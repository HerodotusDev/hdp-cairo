from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class StarknetStateFunctionId(Enum):
    GET_SLOT = 0

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
    address: int
    storage_slot: int

    @classmethod
    def from_int(cls, values: List[int]):
        if len(values) != cls.size():
            raise ValueError(
                "MemorizerKey must be initialized with a list of five integers"
            )

        return cls(values[0], values[1], values[2], values[3])

    def derive(self) -> int:
        return poseidon_hash_many(
            [
                self.chain_id,
                self.block_number,
                self.address,
                self.storage_slot,
            ]
        )

    def to_dict(self):

        return {
            "chain_id": hex(self.chain_id),
            "block_number": self.block_number,
            "address": f"0x{self.address:040x}",
            "key": hex(self.storage_slot),
        }

    @classmethod
    def size(cls) -> int:
        return 4


class AbstractStarknetStorageBase(ABC):
    def __init__(self, memorizer: StarknetMemorizer):
        self.memorizer = memorizer
        self.function_map = {
            StarknetStateFunctionId.GET_SLOT: self.get_slot,
        }

    def handle(
        self, function_id: StarknetStateFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_slot(self, key: MemorizerKey) -> int:
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
