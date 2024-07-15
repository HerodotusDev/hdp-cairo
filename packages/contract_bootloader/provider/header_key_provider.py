from contract_bootloader.memorizer.header_memorizer import (
    MemorizerKey as HeaderMemorizerKey,
)
from contract_bootloader.provider.evm_provider import EVMProvider


class HeaderKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)

    def get_parent(self, key: HeaderMemorizerKey) -> int:
        try:
            # Fetch the block details
            block = self.web3.eth.get_block(key.block_number)
            # Get the parent block number
            parent_block_number = block["parentHash"]
            return int(parent_block_number)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the parent block: {e}")
