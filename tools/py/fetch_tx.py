import time
import math
import json
from typing import Union, List
from tools.py.utils import rpc_request

from tools.py.transaction import (
    LegacyTx,
    Eip155,
    Eip1559,
    Eip2930,
    Eip4844,
    build_tx
)


def fetch_tx_from_rpc(
    tx_hash: str, rpc_url: str
) -> Union[LegacyTx, Eip155, Eip1559, Eip2930, Eip4844]:
    result = rpc_request(rpc_url,  {
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByHash",
        "params": [tx_hash],
    })
    
    tx: Union[
        LegacyTx, Eip155, Eip1559, Eip2930, Eip4844
    ] = build_tx(result["result"])

    return tx