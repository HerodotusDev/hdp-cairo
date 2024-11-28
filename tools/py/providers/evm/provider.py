import json
import requests
from tools.py.types.evm.storage import FeltStorage
from web3.types import BlockData, TxParams

from tools.py.types.evm.account import Account, FeltAccount
from tools.py.types.evm.header import BlockHeader, FeltBlockHeader
from tools.py.types.evm.tx import Tx, FeltTx
from tools.py.types.evm.receipt import Receipt, FeltReceipt
from contract_bootloader.memorizer.evm.header import (
    MemorizerKey as BlockHeaderMemorizerKey,
)
from contract_bootloader.memorizer.evm.account import (
    MemorizerKey as AccountMemorizerKey,
)
from contract_bootloader.memorizer.evm.block_receipt import (
    MemorizerKey as BlockReceiptMemorizerKey,
)
from contract_bootloader.memorizer.evm.block_tx import (
    MemorizerKey as BlockTxMemorizerKey,
)
from contract_bootloader.memorizer.evm.storage import (
    MemorizerKey as StorageMemorizerKey,
)


class EvmProviderBase:
    def __init__(self, rpc_url: str, chain_id: int):
        self.rpc_url = rpc_url
        self.chain_id = chain_id

    def rpc_request(self, rpc_request):
        headers = {"Content-Type": "application/json"}
        response = requests.post(
            url=self.rpc_url, headers=headers, data=json.dumps(rpc_request)
        )
        return response.json()


class EvmProvider(EvmProviderBase):
    def __init__(self, rpc_url: str, chain_id: int):
        super().__init__(rpc_url, chain_id)

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

    def get_rpc_block_header_by_hash(self, block_hash: str) -> BlockData:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByHash",
                "params": [block_hash, False],
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

        return Tx.from_rpc_data(self.chain_id, result["result"])

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
                "jsonrpc": "2.0",
                "method": "eth_getProof",
                "params": [address, [], hex(block_number)],
                "id": 1,
            }
        )

        return Account.from_rpc_data(result["result"])

    def get_rpc_account_by_address(self, address: str, block_number: int) -> Account:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getProof",
                "params": [address, [], hex(block_number)],
                "id": 1,
            }
        )

        return result["result"]

    def get_receipt_by_hash(self, transaction_hash: str) -> Receipt:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getTransactionReceipt",
                "params": [transaction_hash],
                "id": 1,
            }
        )

        return Receipt.from_rpc_data(result["result"])

    def get_rpc_receipt_by_hash(self, transaction_hash: str) -> dict:
        print(f"Getting receipt for {transaction_hash}")
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getTransactionReceipt",
                "params": [transaction_hash],
                "id": 1,
            }
        )

        print(f"result: {result}")

        return result["result"]


class EvmKeyProvider(EvmProviderBase):
    def __init__(self, rpc_url: str, chain_id: int):
        super().__init__(rpc_url, chain_id)

    def get_block_header(self, key: BlockHeaderMemorizerKey) -> FeltBlockHeader:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByNumber",
                "params": [hex(key.block_number), False],
            },
        )

        return FeltBlockHeader.from_rpc_data(result["result"])

    def get_block_tx(self, key: BlockTxMemorizerKey) -> FeltTx:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByNumber",
                "params": [hex(key.block_number), True],
            },
        )

        return FeltTx.from_rpc_data(key, result["result"]["transactions"][key.index])

    def get_account(self, key: AccountMemorizerKey) -> FeltAccount:
        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getProof",
                "params": [hex(key.address), [], hex(key.block_number)],
                "id": 1,
            }
        )

        return FeltAccount.from_rpc_data(result["result"])

    def get_block_receipt(self, key: BlockReceiptMemorizerKey) -> FeltReceipt:
        block_result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "id": 1,
                "method": "eth_getBlockByNumber",
                "params": [hex(key.block_number), True],
            },
        )
        tx_hash = block_result["result"]["transactions"][key.index]["hash"]

        receipt_result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getTransactionReceipt",
                "params": [tx_hash],
                "id": 1,
            }
        )

        return FeltReceipt.from_rpc_data(receipt_result["result"])

    def get_storage(self, key: StorageMemorizerKey) -> FeltStorage:
        slot_key = key.storage_slot[0] << 128 | key.storage_slot[1]

        result = self.rpc_request(
            {
                "jsonrpc": "2.0",
                "method": "eth_getStorageAt",
                "params": [hex(key.address), hex(slot_key), hex(key.block_number)],
                "id": 1,
            }
        )

        return FeltStorage.from_rpc_data(result["result"])
