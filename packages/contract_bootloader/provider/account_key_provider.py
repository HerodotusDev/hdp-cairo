from web3 import Web3
from contract_bootloader.memorizer.account_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class AccountKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)

    def get_nonce(self, key: MemorizerKey) -> int:
        address = Web3.to_checksum_address(f"0x{key.address:040x}")
        if not self.web3.is_address(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            nonce = self.web3.eth.get_transaction_count(
                address, block_identifier=key.block_number
            )
            return int(nonce)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the nonce: {e}")

    def get_balance(self, key: MemorizerKey) -> int:
        address = Web3.to_checksum_address(f"0x{key.address:040x}")
        if not self.web3.is_address(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            balance = self.web3.eth.get_balance(
                address, block_identifier=key.block_number
            )
            return int(balance)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the balance: {e}")

    def get_state_root(self, key: MemorizerKey) -> int:
        try:
            block = self.web3.eth.get_block(key.block_number)
            return int(block["stateRoot"].hex(), 16)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the state root: {e}")

    def get_code_hash(self, key: MemorizerKey) -> int:
        address = Web3.to_checksum_address(f"0x{key.address:040x}")
        if not self.web3.is_address(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            code = self.web3.eth.get_code(address, block_identifier=key.block_number)
            return int(Web3.keccak(code).hex(), 16)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the code hash: {e}")
