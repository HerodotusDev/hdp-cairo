from contract_bootloader.memorizer.account_memorizer import (
    MemorizerKey as AccountMemorizerKey,
)
from packages.contract_bootloader.provider.evm_provider import EVMProvider


class AccountKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)

    def get_balance(self, key: AccountMemorizerKey):
        if not self.web3.isAddress(key.address):
            raise ValueError(f"Invalid Ethereum address: {key.address}")

        try:
            balance = self.web3.eth.get_balance(
                key.address, block_identifier=key.block_number
            )
            return int(balance)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the balance: {e}")
