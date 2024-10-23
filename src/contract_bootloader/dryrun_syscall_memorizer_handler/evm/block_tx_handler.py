from typing import Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.block_tx import (
    AbstractEvmBlockTxBase,
    MemorizerKey,
)
from tools.py.providers.evm.provider import EvmKeyProvider


class DryRunEvmBlockTxHandler(AbstractEvmBlockTxBase):
    def __init__(self, memorizer: EvmMemorizer, provider: EvmKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).nonce()

    def get_gas_price(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).gas_price()

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).gas_limit()

    def get_receiver(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).receiver()

    def get_value(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).value()

    def get_input(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_v(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).v()

    def get_r(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).r()

    def get_s(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).s()

    def get_chain_id(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).chain_id()

    def get_access_list(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).max_priority_fee_per_gas()

    def get_max_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).max_fee_per_gas()

    def get_blob_versioned_hashes(self, key: MemorizerKey) -> Tuple[int, int]:
        pass

    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).max_fee_per_blob_gas()

    def get_tx_type(self, key: MemorizerKey) -> Tuple[int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).type()

    def get_sender(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_tx(key=key).sender()

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "EvmBlockTxKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
