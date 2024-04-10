from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async
from starkware.cairo.common.poseidon_hash import poseidon_hash_many, poseidon_hash
from tools.py.utils import bytes_to_8_bytes_chunks, bytes_to_8_bytes_chunks_little
from dotenv import load_dotenv
import os


GOERLI = "goerli"
MAINNET = "mainnet"

NETWORK = GOERLI
load_dotenv()
RPC_URL = (
    os.getenv("RPC_URL_GOERLI") if NETWORK == GOERLI else os.getenv("RPC_URL_MAINNET")
)
RPC_URL = "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"

block_n = 1150001


def get_block_header(number: int):
    blocks = fetch_blocks_from_rpc_no_async(number + 1, number - 1, RPC_URL)
    block = blocks[1]
    print(block)
    assert block.number == number, f"Block number mismatch {block.number} != {number}"
    return block


def get_block_header_raw(number: int):
    block = get_block_header(number)
    print(block.raw_rlp().hex())
    return block.raw_rlp()


def get_poseidon_hash_block(block_header_raw: bytes):
    chunks = bytes_to_8_bytes_chunks(block_header_raw)
    print(chunks, len(chunks))
    return poseidon_hash_many(chunks)


def get_poseidon_hash_block_little(block_header_raw: bytes):
    chunks = bytes_to_8_bytes_chunks_little(block_header_raw)
    print([hex(chunk) for chunk in chunks], len(chunks))
    return poseidon_hash_many(chunks)


test = get_block_header_raw(block_n)
# test_big = get_poseidon_hash_block(test)
test_little = get_poseidon_hash_block_little(test)
print(hex(test_little))
