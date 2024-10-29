from typing import Tuple
from contract_bootloader.memorizer.evm.memorizer import EvmMemorizer
from contract_bootloader.memorizer.evm.header import (
    AbstractEvmHeaderBase,
    MemorizerKey,
)
from tools.py.providers.evm.provider import EvmKeyProvider


class DryRunEvmHeaderHandler(AbstractEvmHeaderBase):
    def __init__(self, memorizer: EvmMemorizer, provider: EvmKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_parent(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).parent_hash()

    def get_uncle(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).uncles_hash()

    def get_coinbase(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).coinbase()

    def get_state_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).state_root()

    def get_transaction_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).transactions_root()

    def get_receipt_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).receipts_root()

    def get_bloom(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).logs_bloom()

    def get_difficulty(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).difficulty()

    def get_number(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).number()

    def get_gas_limit(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).gas_limit()

    def get_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).gas_used()

    def get_timestamp(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).timestamp()

    def get_extra_data(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).extra_data()

    def get_mix_hash(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).mix_hash()

    def get_nonce(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).nonce()

    def get_base_fee_per_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).base_fee_per_gas()

    def get_withdrawals_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).withdrawals_root()

    def get_blob_gas_used(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).blob_gas_used()

    def get_excess_blob_gas(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).excess_blob_gas()

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> Tuple[int, int]:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).parent_beacon_block_root()

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "EvmHeaderKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
