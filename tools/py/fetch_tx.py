import time
import math
import json
from typing import Union, List
from tools.py.utils import rpc_request

from tools.py.transaction import (
    LegacyTx,
    Eip155,
    build_tx
)


def fetch_tx_from_rpc(
    tx_hash: str, rpc_url: str
) -> Union[LegacyTx]:
    result = rpc_request(rpc_url,  {
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByHash",
        "params": [tx_hash],
    })

    print("Result: ", result)
    
    tx: Union[
        LegacyTx, Eip155
    ] = build_tx(result["result"])

    print(tx.hash().hex())

    return tx


# def get_block_header(number: int, RPC_URL: str):
#     blocks = fetch_blocks_from_rpc_no_async(number + 1, number - 1, RPC_URL)
#     block = blocks[1]
#     assert block.number == number, f"Block number mismatch {block.number} != {number}"
#     return block
