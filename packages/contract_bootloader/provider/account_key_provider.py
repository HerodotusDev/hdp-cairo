from web3 import Web3
from contract_bootloader.memorizer.account_memorizer import (
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.provider.evm_provider import EVMProvider


class AccountKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)

    def get_balance(self, key: AccountMemorizerKey):
        address = Web3.toChecksumAddress(hex(key.address))
        if not self.web3.isAddress(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            balance = self.web3.eth.get_balance(
                address, block_identifier=key.block_number
            )
            return int(balance)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the balance: {e}")
