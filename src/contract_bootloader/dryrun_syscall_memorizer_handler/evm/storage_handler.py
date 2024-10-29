from typing import Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.storage import (
    AbstractEvmStorageBase,
    MemorizerKey,
)
from tools.py.providers.evm.provider import EvmKeyProvider


class DryRunEvmStorageHandler(AbstractEvmStorageBase):
    def __init__(self, memorizer: EvmMemorizer, provider: EvmKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_slot(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_storage(key=key).value

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "EvmStorageKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
