from web3.types import TxData
from contract_bootloader.memorizer.block_tx_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class BlockTxKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)
        self.block_cache = {}
        self.tx_cache = {}

    def get_block_tx(self, key: MemorizerKey) -> TxData:
        if key in self.tx_cache:
            return self.tx_cache[key]

        if key.block_number in self.block_cache:
            block = self.block_cache[key.block_number]
        else:
            try:
                # Fetch the block details
                block = self.web3.eth.get_block(
                    key.block_number, full_transactions=True
                )
                # Cache the fetched block
                self.block_cache[key.block_number] = block
            except Exception as e:
                raise Exception(
                    f"An error occurred while fetching the parent block: {e}"
                )

        tx: TxData = block["transactions"][key.index]
        self.tx_cache[key] = tx
        return tx

    def get_nonce(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return tx["nonce"]

    def get_gas_price(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return tx["gasPrice"]

    def get_gas_limit(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return tx["gas"]

    def get_receiver(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return int(tx["to"], 16)

    def get_value(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return tx["value"]

    def get_input(self, key: MemorizerKey) -> int:
        pass

    def get_v(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return tx["v"]

    def get_r(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return int(tx["r"].hex(), 16)

    def get_s(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return int(tx["s"].hex(), 16)

    def get_chain_id(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        assert int(tx["version"], 16) != 0, "Legacy Txs don't have chain id"

        return int(tx["chainId"], 16)

    def get_access_list(self, key: MemorizerKey) -> int:
        pass

    def get_max_fee_per_gas(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        assert (
            int(tx["version"], 16) < 2
        ), "Legacy/EIP2930 Txs don't have max_fee_per_gas"

        return tx["maxFeePerGas"]

    def get_max_priority_fee_per_gas(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        assert (
            int(tx["version"], 16) < 2
        ), "Legacy/EIP2930 Txs don't have max_priority_fee_per_gas"

        return tx["maxPriorityFeePerGas"]

    def get_blob_versioned_hashes(self, key: MemorizerKey) -> int:
        pass

    def get_max_fee_per_blob_gas(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        assert int(tx["version"], 16) == 3, "Only EIP4844 Txs have max_fee_per_blob_gas"

        return tx["maxFeePerBlobGas"]

    def get_tx_type(self, key: MemorizerKey) -> int:
        tx = self.get_block_tx(key)
        return int(tx["type"], 16)