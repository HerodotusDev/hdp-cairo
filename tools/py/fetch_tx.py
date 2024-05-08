import time
import math
import json
from typing import Union, List
from tools.py.utils import rpc_request

from tools.py.transaction import LegacyTx, Eip155, Eip1559, Eip2930, Eip4844, build_tx


def fetch_block_tx_ids_from_rpc(block_number: int, rpc_url: str) -> List[str]:
    result = rpc_request(
        rpc_url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getBlockByNumber",
            "params": [hex(block_number), False],
        },
    )

    tx_ids = [tx for tx in result["result"]["transactions"]]
    return tx_ids


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


def fetch_tx_from_rpc(
    tx_hash: str, rpc_url: str
) -> Union[LegacyTx, Eip155, Eip1559, Eip2930, Eip4844]:
    result = rpc_request(
        rpc_url,
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_getTransactionByHash",
            "params": [tx_hash],
        },
    )

    tx: Union[LegacyTx, Eip155, Eip1559, Eip2930, Eip4844] = build_tx(result["result"])
    # print(tx.raw_rlp().hex())
    return tx
