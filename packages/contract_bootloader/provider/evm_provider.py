from abc import ABC
from web3 import Web3


class EVMProvider(ABC):
    def __init__(self, provider_url: str):
        self.web3 = Web3(Web3.HTTPProvider(provider_url))
        if not self.web3.isConnected():
            raise ValueError(
                f"Failed to connect to the Ethereum node at {provider_url}"
            )
