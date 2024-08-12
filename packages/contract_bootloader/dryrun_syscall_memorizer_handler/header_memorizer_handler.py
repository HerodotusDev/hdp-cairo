from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.header_memorizer import (
    AbstractHeaderMemorizerBase,
    MemorizerKey,
)
from contract_bootloader.provider.header_key_provider import HeaderKeyEVMProvider
from tools.py.utils import split_128


class DryRunHeaderMemorizerHandler(AbstractHeaderMemorizerBase):
    def __init__(self, memorizer: Memorizer, evm_provider_url: str):
        super().__init__(memorizer=memorizer)
        self.evm_provider = HeaderKeyEVMProvider(provider_url=evm_provider_url)
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_parent(key=key)
        return split_128(value)

    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_uncle(key=key)
        return split_128(value)

    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_coinbase(key=key)
        return split_128(value)

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_state_root(key=key)
        return split_128(value)

    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_transaction_root(key=key)
        return split_128(value)

    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_receipt_root(key=key)
        return split_128(value)

    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_bloom(key=key)
        return split_128(value)

    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_difficulty(key=key)
        return split_128(value)

    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_number(key=key)
        return split_128(value)

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_gas_limit(key=key)
        return split_128(value)

    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_gas_used(key=key)
        return split_128(value)

    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_timestamp(key=key)
        return split_128(value)

    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_extra_data(key=key)
        return split_128(value)

    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_mix_hash(key=key)
        return split_128(value)

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_nonce(key=key)
        return split_128(value)

    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_base_fee_per_gas(key=key)
        return split_128(value)

    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_withdrawals_root(key=key)
        return split_128(value)

    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_blob_gas_used(key=key)
        return split_128(value)

    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_excess_blob_gas(key=key)
        return split_128(value)

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_parent_beacon_block_root(key=key)
        return split_128(value)

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "HeaderMemorizerKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
