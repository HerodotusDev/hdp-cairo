from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.storage_memorizer import (
    AbstractStorageMemorizerBase,
    MemorizerKey,
)
from contract_bootloader.provider.storage_key_provider import StorageKeyEVMProvider

from tools.py.utils import split_128


class DryRunStorageMemorizerHandler(AbstractStorageMemorizerBase):
    def __init__(self, memorizer: Memorizer, evm_provider_url: str):
        super().__init__(memorizer=memorizer)
        self.evm_provider = StorageKeyEVMProvider(provider_url=evm_provider_url)
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_slot(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        value = self.evm_provider.get_slot(key=key)
        return split_128(value)

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "StorageMemorizerKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
