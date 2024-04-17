from tools.py.fetch_tx import fetch_tx_from_rpc
from tools.py.transaction import LegacyTx
from rlp import encode
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


def fetch_tx(tx_hash):
    return fetch_tx_from_rpc(tx_hash, RPC_URL)


def fetch_transaction_dict(tx_hash):
    tx = fetch_tx(tx_hash)
    rlp = bytes_to_8_bytes_chunks_little(tx.raw_rlp())

    tx_dict = {
        "rlp": rlp,
        "rlp_bytes_len": len(tx.raw_rlp()),
        "block_number": tx.block_number,
    }

    # LE
    (low, high) = reverse_and_split_256_bytes(tx.nonce.to_bytes(32, "big"))
    tx_dict["nonce"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(tx.gas_limit.to_bytes(32, "big"))
    tx_dict["gas_limit"] = {"low": low, "high": high}

    to = bytes_to_8_bytes_chunks_little(tx.to)
    tx_dict["receiver"] = to

    (low, high) = reverse_and_split_256_bytes(tx.value.to_bytes(32, "big"))
    tx_dict["value"] = {"low": low, "high": high}

    data = bytes_to_8_bytes_chunks_little(tx.data)
    tx_dict["data"] = data

    (low, high) = reverse_and_split_256_bytes(tx.v.to_bytes(32, "big"))
    tx_dict["v"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(tx.r)
    tx_dict["r"] = {"low": low, "high": high}

    (low, high) = reverse_and_split_256_bytes(tx.s)
    tx_dict["s"] = {"low": low, "high": high}

    input_bytes = tx.data
    if tx.data == b"":
        tx_dict["input"] = {
            "chunks": [0],
            "bytes_len": 1,
        }
    else:
        tx_dict["input"] = {
            "chunks": bytes_to_8_bytes_chunks_little(tx.data),
            "bytes_len": len(tx.data),
        }

    tx_dict["type"] = tx.type
    tx_dict["sender"] = int(tx.sender.hex(), 16)

    if type(tx) != LegacyTx:
        tx_dict["chain_id"] = tx.chain_id

    if tx.type <= 1:
        (low, high) = reverse_and_split_256_bytes(tx.gas_price.to_bytes(32, "big"))
        tx_dict["gas_price"] = {"low": low, "high": high}
    else:
        (low, high) = reverse_and_split_256_bytes(
            tx.max_priority_fee_per_gas.to_bytes(32, "big")
        )
        tx_dict["max_priority_fee_per_gas"] = {"low": low, "high": high}

        (low, high) = reverse_and_split_256_bytes(
            tx.max_fee_per_gas.to_bytes(32, "big")
        )
        tx_dict["max_fee_per_gas"] = {"low": low, "high": high}

    if tx.type >= 1:
        if len(tx.access_list) == 0:
            tx_dict["access_list"] = {
                "chunks": [0],
                "bytes_len": 1,
            }
        else:
            access_list_bytes = encode(tx.access_list)  # we need to remove the prefix
            tx_dict["access_list"] = {
                "chunks": bytes_to_8_bytes_chunks_little(
                    encode_array_elements(access_list_bytes)
                ),
                "bytes_len": len(encode_array_elements(access_list_bytes)),
            }

    if tx.type == 3:
        (low, high) = reverse_and_split_256_bytes(
            tx.max_fee_per_blob_gas.to_bytes(32, "big")
        )
        tx_dict["max_fee_per_blob_gas"] = {"low": low, "high": high}

        if len(tx.blob_versioned_hashes) == 0:
            tx_dict["blob_versioned_hashes"] = {
                "chunks": [0],
                "bytes_len": 1,
            }
        else:
            tx_dict["blob_versioned_hashes"] = {
                "chunks": bytes_to_8_bytes_chunks_little(
                    encode_array_elements(tx.blob_versioned_hashes)
                ),
                "bytes_len": len(encode_array_elements(tx.blob_versioned_hashes)),
            }

    return tx_dict


def encode_array_elements(hex_array):
    res = b""
    for element in hex_array:
        res += encode(element)

    return res


## Test TX encoding:
# assert fetch_tx("0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021").hash().hex() == "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021"
# assert fetch_tx("0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51").hash().hex() == "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51"
# assert fetch_tx("0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b").hash().hex() == "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b"
# assert fetch_tx("0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b").hash().hex() == "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b"
# assert fetch_tx("0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9").hash().hex() == "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9"
