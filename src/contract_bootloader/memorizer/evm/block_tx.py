from web3 import Web3
from enum import Enum
from typing import List, Tuple
from abc import ABC, abstractmethod
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from marshmallow_dataclass import dataclass
from starkware.cairo.lang.vm.crypto import poseidon_hash_many
from starkware.cairo.lang.vm.relocatable import RelocatableValue


class EvmStateFunctionId(Enum):
    GET_NONCE = 0
    GET_GAS_PRICE = 1
    GET_GAS_LIMIT = 2
    GET_RECEIVER = 3
    GET_VALUE = 4
    GET_INPUT = 5
    GET_V = 6
    GET_R = 7
    GET_S = 8
    GET_CHAIN_ID = 9
    GET_ACCESS_LIST = 10
    GET_MAX_FEE_PER_GAS = 11
    GET_MAX_PRIORITY_FEE_PER_GAS = 12
    GET_MAX_FEE_PER_BLOB_GAS = 13
    GET_BLOB_VERSIONED_HASHES = 14
    GET_TX_TYPE = 15
    GET_SENDER = 16

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
            "chain_id": hex(self.chain_id),
            "block_number": self.block_number,
            "index": self.index,
        }

    @classmethod
    def size(cls) -> int:
        return 3


class AbstractEvmBlockTxBase(ABC):
    def __init__(self, memorizer: EvmMemorizer):
        self.memorizer = memorizer
        self.function_map = {
            EvmStateFunctionId.GET_NONCE: self.get_nonce,
            EvmStateFunctionId.GET_GAS_PRICE: self.get_gas_price,
            EvmStateFunctionId.GET_GAS_LIMIT: self.get_gas_limit,
            EvmStateFunctionId.GET_RECEIVER: self.get_receiver,
            EvmStateFunctionId.GET_VALUE: self.get_value,
            EvmStateFunctionId.GET_INPUT: self.get_input,
            EvmStateFunctionId.GET_V: self.get_v,
            EvmStateFunctionId.GET_R: self.get_r,
            EvmStateFunctionId.GET_S: self.get_s,
            EvmStateFunctionId.GET_CHAIN_ID: self.get_chain_id,
            EvmStateFunctionId.GET_ACCESS_LIST: self.get_access_list,
            EvmStateFunctionId.GET_MAX_FEE_PER_GAS: self.get_max_fee_per_gas,
            EvmStateFunctionId.GET_MAX_PRIORITY_FEE_PER_GAS: self.get_max_priority_fee_per_gas,
            EvmStateFunctionId.GET_MAX_FEE_PER_BLOB_GAS: self.get_max_fee_per_blob_gas,
            EvmStateFunctionId.GET_BLOB_VERSIONED_HASHES: self.get_blob_versioned_hashes,
            EvmStateFunctionId.GET_TX_TYPE: self.get_tx_type,
            EvmStateFunctionId.GET_SENDER: self.get_sender,
        }

    def handle(
        self, function_id: EvmStateFunctionId, key: MemorizerKey
    ) -> Tuple[int, int]:
        if function_id in self.function_map:
            return self.function_map[function_id](key=key)
        else:
            raise ValueError(f"Function ID {function_id} is not recognized.")

    @abstractmethod
    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_gas_price(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_receiver(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_value(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_input(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_v(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_r(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_s(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_chain_id(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_access_list(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_max_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_blob_versioned_hashes(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_tx_type(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    @abstractmethod
    def get_sender(self, key: MemorizerKey) -> Tuple[int, int]:
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
