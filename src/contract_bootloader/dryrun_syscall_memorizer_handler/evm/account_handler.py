from typing import Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.account import (
    AbstractEvmAccountBase,
    MemorizerKey,
)
from tools.py.providers.evm.provider import EvmKeyProvider


class DryRunEvmAccountHandler(AbstractEvmAccountBase):
    def __init__(self, memorizer: EvmMemorizer, provider: EvmKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_account(key=key).nonce()

    def get_balance(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_account(key=key).balance()

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_account(key=key).storage_hash()

    def get_code_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_account(key=key).code_hash()

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "EvmAccountKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
