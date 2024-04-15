from tools.py.fetch_tx import fetch_tx_from_rpc
from tools.py.transaction import LegacyTx
from starkware.cairo.common.poseidon_hash import poseidon_hash_many, poseidon_hash
from tools.py.utils import bytes_to_8_bytes_chunks, bytes_to_8_bytes_chunks_little, split_128, reverse_endian_256, reverse_endian_bytes, reverse_and_split_256_bytes
from dotenv import load_dotenv
import os
import math


GOERLI = "goerli"
MAINNET = "mainnet"

NETWORK = MAINNET
load_dotenv()
RPC_URL = (
    os.getenv("RPC_URL_GOERLI") if NETWORK == GOERLI else os.getenv("RPC_URL_MAINNET")
)

def fetch_tx(tx_hash):
    tx = fetch_tx_from_rpc(tx_hash, RPC_URL)
    print(tx)
    # block = blocks[1]
    # assert block.number == block_number, f"Block number mismatch {block.number} != {block_number}"
    # return block


# fetch_tx("0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021")
# fetch_tx("0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51")
# fetch_tx("0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b")
# fetch_tx("0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b")
fetch_tx("0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9")