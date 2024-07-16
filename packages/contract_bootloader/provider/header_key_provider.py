from web3.types import BlockData
from contract_bootloader.memorizer.header_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class HeaderKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)

    def get_block(self, key: MemorizerKey) -> BlockData:
        try:
            # Fetch the block details
            return self.web3.eth.get_block(key.block_number)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the parent block: {e}")
