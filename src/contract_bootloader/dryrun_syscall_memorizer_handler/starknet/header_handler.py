from contract_bootloader.memorizer.starknet.memorizer import StarknetMemorizer
from contract_bootloader.memorizer.starknet.header import (
    AbstractStarknetHeaderBase,
    MemorizerKey,
)
from tools.py.providers.starknet.provider import StarknetKeyProvider


class DryRunStarknetHeaderHandler(AbstractStarknetHeaderBase):
    def __init__(self, memorizer: StarknetMemorizer, provider: StarknetKeyProvider):
        super().__init__(memorizer=memorizer)
        self.provider = provider
        self.fetch_keys_registry: set[MemorizerKey] = set()

    def get_block_hash(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).hash

    def get_parent_block_hash(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).parent_block_hash

    def get_block_number(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).block_number

    def get_state_root(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).state_root

    def get_sequencer_address(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).sequencer_address

    def get_block_timestamp(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).block_timestamp

    def get_transaction_count(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).transaction_count

    def get_transaction_commitment(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).transaction_commitment

    def get_event_count(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).event_count

    def get_event_commitment(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).event_commitment

    def get_state_diff_commitment(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).state_diff_commitment

    def get_state_diff_length(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).state_diff_length

    def get_receipts_commitment(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).receipt_commitment

    def get_l1_gas_price_in_wei(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).l1_gas_price_wei

    def get_l1_gas_price_in_fri(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).l1_gas_price_fri

    def get_l1_data_gas_price_in_wei(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).l1_data_gas_price_wei

    def get_l1_data_gas_price_in_fri(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).l1_data_gas_price_fri

    def get_l1_data_mode(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return self.provider.get_block_header(key=key).l1_da_mode

    def get_protocol_version(self, key: MemorizerKey) -> int:
        self.fetch_keys_registry.add(key)
        return int(self.provider.get_block_header(key=key).protocol_version)

    def fetch_keys_dict(self) -> set:
        def create_dict(key: MemorizerKey):
            data = dict()
            data["type"] = "StarknetHeaderKey"
            data["key"] = key.to_dict()
            return data

        dictionary = dict()
        for fetch_key in list(self.fetch_keys_registry):
            dictionary.update(create_dict(fetch_key))
        return dictionary
