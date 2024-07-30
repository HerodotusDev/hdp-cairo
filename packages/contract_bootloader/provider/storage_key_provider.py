from web3 import Web3
from contract_bootloader.memorizer.storage_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class StorageKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)
        self.slot_cache = {}

    def get_slot(self, key: MemorizerKey) -> int:
        address = Web3.toChecksumAddress(f"0x{key.address:040x}")
        if not self.web3.isAddress(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        # Combine the storage slot tuple into a single slot key
        slot_key = key.storage_slot[0] << 128 | key.storage_slot[1]

        if key in self.slot_cache:
            return self.slot_cache[key]

        try:
            # Fetch the storage slot data
            slot_data = self.web3.eth.get_storage_at(
                address, slot_key, block_identifier=key.block_number
            )
            slot_value = int(slot_data.hex(), 16)
            self.slot_cache[key] = slot_value
            return slot_value
        except Exception as e:
            raise Exception(f"An error occurred while fetching the storage slot: {e}")
