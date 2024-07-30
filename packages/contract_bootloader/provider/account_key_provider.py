import os
from web3 import Web3
from contract_bootloader.memorizer.account_memorizer import MemorizerKey
from contract_bootloader.provider.evm_provider import EVMProvider


class AccountKeyEVMProvider(EVMProvider):
    def __init__(self, provider_url: str):
        super().__init__(provider_url=provider_url)
        self.nonce_cache = {}
        self.balance_cache = {}
        self.state_root_cache = {}
        self.code_hash_cache = {}

    def get_nonce(self, key: MemorizerKey) -> int:
        if key in self.nonce_cache:
            return self.nonce_cache[key]

        address = Web3.toChecksumAddress(f"0x{key.address:040x}")
        if not self.web3.isAddress(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            nonce = self.web3.eth.get_transaction_count(
                address, block_identifier=key.block_number
            )
            self.nonce_cache[key] = int(nonce)
            return int(nonce)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the nonce: {e}")

    def get_balance(self, key: MemorizerKey) -> int:
        if key in self.balance_cache:
            return self.balance_cache[key]

        address = Web3.toChecksumAddress(f"0x{key.address:040x}")
        if not self.web3.isAddress(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            balance = self.web3.eth.get_balance(
                address, block_identifier=key.block_number
            )
            self.balance_cache[key] = int(balance)
            return int(balance)
        except Exception as e:
            raise Exception(f"An error occurred while fetching the balance: {e}")

    def get_state_root(self, key: MemorizerKey) -> int:
        if key in self.state_root_cache:
            return self.state_root_cache[key]

        try:
            address = Web3.toChecksumAddress(f"0x{key.address:040x}")
            account_proof = self.web3.eth.get_proof(address, [], key.block_number)
            state_root = account_proof["storageHash"]
            state_root_int = int(state_root.hex(), 16)
            self.state_root_cache[key] = state_root_int
            return state_root_int
        except Exception as e:
            raise Exception(f"An error occurred while fetching the state root: {e}")

    def get_code_hash(self, key: MemorizerKey) -> int:
        if key in self.code_hash_cache:
            return self.code_hash_cache[key]

        address = Web3.toChecksumAddress(f"0x{key.address:040x}")
        if not self.web3.isAddress(address):
            raise ValueError(f"Invalid Ethereum address: {address}")

        try:
            code = self.web3.eth.get_code(address, block_identifier=key.block_number)
            code_hash = int(Web3.keccak(code).hex(), 16)
            self.code_hash_cache[key] = code_hash
            return code_hash
        except Exception as e:
            raise Exception(f"An error occurred while fetching the code hash: {e}")
