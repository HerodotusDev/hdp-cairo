import time
import math
import json
from typing import Union, List
from tools.py.utils import rpc_request

from tools.py.receipt import Receipt, build_receipt


def fetch_block_receipt_ids_from_rpc(block_number: int, rpc_url: str) -> List[str]:
    result = rpc_request(
        rpc_url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getBlockByNumber",
            "params": [hex(block_number), False],
        },
    )

    receipt_ids = [receipt for receipt in result["result"]["transactions"]]
    return receipt_ids


def fetch_latest_block_height_from_rpc(rpc_url: str) -> int:
    result = rpc_request(
        rpc_url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_blockNumber",
            "params": [],
        },
    )

    return int(result["result"], 16)


def fetch_receipt_from_rpc(receipt_hash: str, rpc_url: str) -> Receipt:
    time.sleep(0.4)
    result = rpc_request(
        rpc_url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getTransactionReceipt",
            "params": [receipt_hash],
        },
    )
    receipt = build_receipt(result["result"])
    return receipt
