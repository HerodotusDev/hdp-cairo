from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from contract_bootloader.memorizer.starknet.storage import (
    AbstractStarknetStorageBase,
    MemorizerKey,
)
from tools.py.providers.starknet.provider import StarknetKeyProvider


class DryRunStarknetStorageHandler(AbstractStarknetStorageBase):
    def __init__(self, memorizer: StarknetMemorizer, provider: StarknetKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_slot(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_storage(key=key)

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "StarknetStorageKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
