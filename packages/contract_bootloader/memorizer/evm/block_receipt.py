from web3 import Web3
from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue

class EvmStateFunctionId(Enum):
    GET_SUCCESS = 0
    GET_CUMULATIVE_GAS_USED = 1
    GET_BLOOM = 2

    
    GET_LOGS = 3

    @classmethod
    def from_int(cls, value: int):
        if not isinstance(value, int):
            raise ValueError(f"Value must be an integer, got {type(value)}")
        for member in cls:
            if member.value == value:
                return member
        raise ValueError(f"{value} is not a valid {cls.__name__}")


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
    index: int

    @classmethod
    def from_int(cls, values: List[int]):
        if len(values) != cls.size():
            raise ValueError(
                "MemorizerKey must be initialized with a list of three integers"
            )
        return cls(values[0], values[1], values[2])

    def derive(self) -> int:
        return poseidon_hash_many([self.chain_id, self.block_number, self.index])

    def to_dict(self):
        return {
            "chain_id": self.chain_id,
            "block_number": self.block_number,
            "index": self.index,
        }

    @classmethod
    def size(cls) -> int:
        return 3
    
class AbstractEvmBlockReceiptBase(ABC):
    def __init__(self, memorizer: EvmMemorizer):
        self.memorizer = memorizer
        self.function_map = {
            EvmStateFunctionId.GET_SUCCESS: self.get_success,
            EvmStateFunctionId.GET_CUMULATIVE_GAS_USED: self.get_cumulative_gas_used,
            EvmStateFunctionId.GET_BLOOM: self.get_bloom,
            EvmStateFunctionId.GET_LOGS: self.get_logs,
        }

    def handle(
        self, function_id: EvmStateFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_success(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_cumulative_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_logs(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

