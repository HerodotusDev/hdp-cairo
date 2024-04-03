import time
import math
import json
from typing import Union, List
from tools.py.utils import rpc_request

from tools.py.block_header import (
    build_block_header,
    BlockHeader,
    BlockHeaderEIP1559,
    BlockHeaderShangai,
    BlockHeaderDencun,
)

RPC_BATCH_MAX_SIZE = 1450


def fetch_blocks_from_rpc_no_async(
    range_from: int, range_till: int, rpc_url: str, delay=0.1
) -> List[
    Union[BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun]
]:
    """
    # Fetches blocks from RPC in batches of RPC_BATCH_MAX_SIZE
    # Returns a list of block headers
    # Params:
    #   range_from: int - the block number to start fetching from
    #   range_till: int - the block number to stop fetching at
    #   rpc_url: str - the RPC url to fetch from
    #   delay: float - delay between RPC requests (in seconds)
    # Returns:
    #   list - a list of block headers of type BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai or BlockHeaderDencun
    """
    assert range_from > range_till, "Invalid range"
    number_of_blocks = range_from - range_till
    rpc_batches_amount = math.ceil(number_of_blocks / RPC_BATCH_MAX_SIZE)
    last_batch_size = number_of_blocks % RPC_BATCH_MAX_SIZE

    all_results = []

    for i in range(1, rpc_batches_amount + 1):
        current_batch_size = (
            last_batch_size
            if (i == rpc_batches_amount and last_batch_size)
            else RPC_BATCH_MAX_SIZE
        )
        requests = list(
            map(
                lambda j: {
                    "jsonrpc": "2.0",
                    "method": "eth_getBlockByNumber",
                    "params": [
                        hex(range_from - (i - 1) * RPC_BATCH_MAX_SIZE - j),
                        False,
                    ],
                    "id": str(j),
                },
                range(0, current_batch_size),
            )
        )

        # Send all requests in the current batch in a single HTTP request
        results = rpc_request(rpc_url, requests)
        # print(results)
        for result in results:
            block_header: Union[
                BlockHeader, BlockHeaderEIP1559, BlockHeaderShangai, BlockHeaderDencun
            ] = build_block_header(result["result"])
            all_results.append(block_header)

        time.sleep(delay)  # Add delay
    time.sleep(delay)  # Add delay
    return all_results


def get_block_header(number: int, RPC_URL: str):
    blocks = fetch_blocks_from_rpc_no_async(number + 1, number - 1, RPC_URL)
    block = blocks[1]
    assert block.number == number, f"Block number mismatch {block.number} != {number}"
    return block
