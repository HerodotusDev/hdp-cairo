import json
import requests
from web3.types import BlockData, TxParams

from tools.py.types.evm.account import Account
from tools.py.types.evm.header import BlockHeader
from tools.py.types.evm.tx import Tx
from tools.py.types.evm.receipt import Receipt

class EvmProviderBase:
    def __init__(self, rpc_url: str):
        self.rpc_url = rpc_url

    def rpc_request(self, rpc_request):
        headers = {"Content-Type": "application/json"}
        response = requests.post(url=self.rpc_url, headers=headers, data=json.dumps(rpc_request))
        return response.json()


class EvmProvider(EvmProviderBase):
    def __init__(self, rpc_url: str):
        super().__init__(rpc_url)
        
    def get_block_header_by_number(self, block_number: int) -> BlockHeader:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByNumber",
                "params": [hex(block_number), False],
            },
        )

        return BlockHeader.from_rpc_data(result["result"])

    def get_rpc_block_header_by_number(self, block_number: int) -> BlockData:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByNumber",
                "params": [hex(block_number), False],
            },
        )

        return result["result"]

    def get_transaction_by_hash(self, transaction_hash: str) -> Tx:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getTransactionByHash",
                "params": [transaction_hash],
            },
        )

        return Tx.from_rpc_data(result["result"])
    
    def get_rpc_transaction_by_hash(self, transaction_hash: str) -> TxParams:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getTransactionByHash",
                "params": [transaction_hash],
            },
        )

        return result["result"]
        
    def get_account_by_address(self, address: str, block_number: int) -> Account:
        result = self.rpc_request(
            {
                "jsonrpc":"2.0",
                "method":"eth_getProof",
                "params":[address, [], hex(block_number)],
                "id":1
            }
        )

        return Account.from_rpc_data(result["result"])
    
    def get_rpc_account_by_address(self, address: str, block_number: int) -> Account:
        result = self.rpc_request(
            {
                "jsonrpc":"2.0",
                "method":"eth_getProof",
                "params":[address, [], hex(block_number)],
                "id":1
            }
        )

        return result["result"]
    
    def get_receipt_by_hash(self, transaction_hash: str) -> Receipt:
        result = self.rpc_request(
            {
                "jsonrpc":"2.0",
                "method":"eth_getTransactionReceipt",
                "params":[transaction_hash],
                "id":1
            }
        )

        return Receipt.from_rpc_data(result["result"])
    
    def get_rpc_receipt_by_hash(self, transaction_hash: str) -> dict:
        result = self.rpc_request(
            {
                "jsonrpc":"2.0",
                "method":"eth_getTransactionReceipt",
                "params":[transaction_hash],
                "id":1
            }
        )

        return result["result"]
        
