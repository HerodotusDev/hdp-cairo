from web3.types import BlockData
from contract_bootloader.memorizer.header_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class HeaderKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)
        self.block_cache = {}

    def get_block(self, key: MemorizerKey) -> BlockData:
        if key in self.block_cache:
            return self.block_cache[key]

        try:
            # Fetch the block details
            block = self.web3.eth.get_block(key.block_number)
            # Cache the fetched block
            self.block_cache[key] = block
            return block
        except Exception as e:
            raise Exception(f"An error occurred while fetching the parent block: {e}")

    def get_parent(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["parentHash"].hex(), 16)

    def get_uncle(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["sha3Uncles"].hex(), 16)

    def get_coinbase(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["miner"], 16)

    def get_state_root(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["stateRoot"].hex(), 16)

    def get_transaction_root(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["transactionsRoot"].hex(), 16)

    def get_receipt_root(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["receiptsRoot"].hex(), 16)

    def get_bloom(self, key: MemorizerKey) -> int:
        pass

    def get_difficulty(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["difficulty"])

    def get_number(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["number"])

    def get_gas_limit(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["gasLimit"])

    def get_gas_used(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["gasUsed"])

    def get_timestamp(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["timestamp"])

    def get_extra_data(self, key: MemorizerKey) -> int:
        pass

    def get_mix_hash(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["mixHash"].hex(), 16)

    def get_nonce(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["nonce"].hex(), 16)

    def get_base_fee_per_gas(self, key: MemorizerKey) -> int:
        return int(self.get_block(key=key)["baseFeePerGas"])

    def get_withdrawals_root(self, key: MemorizerKey) -> int:
        pass

    def get_blob_gas_used(self, key: MemorizerKey) -> int:
        pass

    def get_excess_blob_gas(self, key: MemorizerKey) -> int:
        pass

    def get_parent_beacon_block_root(self, key: MemorizerKey) -> int:
        pass
