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
            "method": "eth_getTransactionByHash",
            "params": [tx_hash],
        },
    )

    tx: Union[LegacyTx, Eip155, Eip1559, Eip2930, Eip4844] = build_tx(result["result"])
    print(tx.raw_rlp().hex)
    return tx

0xdbe7aeee33496c24651d818f1c67cd82f85092666f36ecb3bd712c6317c4576b
0x8d2c9f198a1a635ac464a21e07cc1f58c2f1cf7cdc9161025c1df38b4c0706