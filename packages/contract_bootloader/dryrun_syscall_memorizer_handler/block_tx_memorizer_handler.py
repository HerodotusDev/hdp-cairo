from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.block_tx_memorizer import (
    AbstractBlockTxMemorizerBase,
    MemorizerKey,
)
from contract_bootloader.provider.block_tx_key_provider import BlockTxKeyEVMProvider
from tools.py.utils import split_128


class DryRunBlockTxMemorizerHandler(AbstractBlockTxMemorizerBase):
    def __init__(self, memorizer: Memorizer, evm_provider_url: str):
        super().__init__(memorizer=memorizer)
        self.evm_provider = BlockTxKeyEVMProvider(provider_url=evm_provider_url)
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_nonce(key=key)
        return split_128(value)

    def get_gas_price(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_gas_price(key=key)
        return split_128(value)

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_gas_limit(key=key)
        return split_128(value)

    def get_receiver(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_receiver(key=key)
        return split_128(value)

    def get_value(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_value(key=key)
        return split_128(value)

    def get_input(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_input(key=key)
        return split_128(value)

    def get_v(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_v(key=key)
        return split_128(value)

    def get_r(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_r(key=key)
        return split_128(value)

    def get_s(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_s(key=key)
        return split_128(value)

    def get_chain_id(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_chain_id(key=key)
        return split_128(value)

    def get_access_list(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_access_list(key=key)
        return split_128(value)

    def get_max_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_max_fee_per_gas(key=key)
        return split_128(value)

    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_max_priority_fee_per_gas(key=key)
        return split_128(value)

    def get_blob_versioned_hashes(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_blob_versioned_hashes(key=key)
        return split_128(value)

    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_max_fee_per_blob_gas(key=key)
        return split_128(value)

    def get_tx_type(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_tx_type(key=key)
        return split_128(value)

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "BlockTxMemorizerKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
