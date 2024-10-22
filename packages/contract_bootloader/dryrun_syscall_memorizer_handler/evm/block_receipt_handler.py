from typing import Tuple
from contract_bootloader.memorizer.memorizer import Memorizer
from contract_bootloader.memorizer.evm.block_receipt import (
    AbstractEvmBlockReceiptBase,
    MemorizerKey,
)
from tools.py.providers.evm.provider import EvmKeyProvider


class DryRunEvmBlockReceiptHandler(AbstractEvmBlockReceiptBase):
    def __init__(self, memorizer: Memorizer, provider: EvmKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_success(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_receipt(key=key).success

    def get_cumulative_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_receipt(key=key).cumulative_gas_used

    # def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
    #     self.fetch_keys_registry.add(key)
    #     return self.provider.get_block_receipt(key=key).bloom

    # def get_logs(self, key: MemorizerKey) -> Tuple[int, int]:
    #     self.fetch_keys_registry.add(key)
    #     return self.provider.get_block_receipt(key=key).logs

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "EvmBlockReceiptKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
