from tools.py.fetch_receipt import (
    fetch_receipt_from_rpc,
    fetch_block_receipt_ids_from_rpc,
    fetch_latest_block_height_from_rpc,
)
from tools.py.transaction import LegacyTx
from rlp import encode, decode
from tools.py.utils import (
    bytes_to_8_bytes_chunks_little,
    reverse_and_split_256_bytes,
)
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


def fetch_latest_block_height():
    return fetch_latest_block_height_from_rpc(RPC_URL)


def fetch_block_receipt_ids(block_number):
    return fetch_block_receipt_ids_from_rpc(block_number, RPC_URL)


def fetch_receipt(receipt_hash):
    return fetch_receipt_from_rpc(receipt_hash, RPC_URL)


def fetch_receipt_dict(receipt_hash):
    receipt = fetch_receipt(receipt_hash)
    rlp = bytes_to_8_bytes_chunks_little(receipt.raw_rlp())

    receipt_dict = {
        "rlp": rlp,
        "rlp_bytes_len": len(receipt.raw_rlp()),
        "block_number": receipt.block_number,
        "type": receipt.type,
    }

    (low, high) = reverse_and_split_256_bytes(receipt.success.to_bytes(32, "big"))
    receipt_dict["success"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(receipt.cumulative_gas_used.to_bytes(32, "big"))
    receipt_dict["cumulative_gas_used"] = {"low": low, "high": high}
    if receipt.bloom == 0:
        receipt_dict["bloom"] = {
            "chunks": [0],
            "bytes_len": 1,
        }
    else:
        chunks = bytes_to_8_bytes_chunks_little(receipt.bloom.to_bytes(256, "big"))
        receipt_dict["bloom"] = {
            "chunks": chunks,
            "bytes_len": len(receipt.bloom.to_bytes(256, "big")),
        }

    if receipt.logs == ():
        receipt_dict["logs"] = {
            "chunks": [0],
            "bytes_len": 1,
        }
    else:
        encoded = encode_array_elements(receipt.logs)
        receipt_dict["logs"] = {
            "chunks": bytes_to_8_bytes_chunks_little(encoded),
            "bytes_len": len(encoded),
        }

    return receipt_dict


# encode an the elements of an array in RLP. This returns the encoded data, without the array prefix
def encode_array_elements(hex_array):
    res = b""
    for element in hex_array:
        res += encode(element)

    return res


# fetch_transaction_dict("0xf6aa201423179851269d045f1f5500fc7e8b8e6090fb3bcc34d3cbc15a9d0218")