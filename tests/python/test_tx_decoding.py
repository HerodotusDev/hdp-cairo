from tools.py.fetch_tx import fetch_tx_from_rpc, fetch_block_tx_ids_from_rpc, fetch_latest_block_height_from_rpc
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

def fetch_block_tx_ids(block_number):
    return fetch_block_tx_ids_from_rpc(block_number, RPC_URL)


def fetch_tx(tx_hash):
    return fetch_tx_from_rpc(tx_hash, RPC_URL)


def fetch_transaction_dict(tx_hash):
    tx = fetch_tx(tx_hash)
    assert tx_hash == tx.hash().hex(), "TX hashes do not match!"
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
            # access_list_bytes = encode(tx.access_list)  # we need to remove the prefix
            encoded = encode_array_elements(tx.access_list)
            # encoded = bytes.fromhex("f89b940cec1a9154ff802e7934fc916ed7ca50bde6844ef884a0232904e972d2518ca5de53b688f0c012d217f9ec2f9e3cc899548e3cff809b91a0b1fb93b8910013300951b58da0a060cac9433f2f7922fb52e4c776e82ff0f788a023e9daf9e960f8ebfeaae9cb4e4f256cf4b871ca175787947bdb69405898d390a04197bb289dd8e91106fd125cbff4a925ec93b6cc467e7e8f9d86ff77bf8ff015f8dd943f2eea452d4717dea05dbe55e1bfaf020294dd97f8c6a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009a0000000000000000000000000000000000000000000000000000000000000000aa0000000000000000000000000000000000000000000000000000000000000000ca00000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000006f859946468e79a80c0eab0f9a2b574c8d5bc374af59414f842a07d08853bb81556269175c6f411c34c38a737ce04c92b81a16551dc926d7a012fa0edb43ec9134ec65b68117c70f52ff4aa42a02316a8828283644328e50f148dd4f8dd94684b00a5773679f88598a19976fbeb25a68e9a5ff8c6a0000000000000000000000000000000000000000000000000000000000000000ca00000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009a0000000000000000000000000000000000000000000000000000000000000000af8bc94a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48f8a5a07050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3a00000000000000000000000000000000000000000000000000000000000000001a0f549ccb0ced49ffd82abc48f7b5682425fced3e45edca2897b43ddc69f2a8e61a0154bb98efc83b034ad81fbf23cc88c9737739df170c146ea18e8113dac893665a010d6a54a4754c8869d6886b5f5d7fbfa5b4522237ea5c60d11bc4e7a1ff9390bf8dd944c99557e563b1596a1552648ca15563605a718ccf8c6a0000000000000000000000000000000000000000000000000000000000000000ca00000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009a0000000000000000000000000000000000000000000000000000000000000000af8dd94e6f47303032a09c8c0f8ebb713c00e6ed345e8c3f8c6a0f05136844516e4b27a065c505c514ff1b0dc0bfa5098c98725fce212510d37d2a00000000000000000000000000000000000000000000000000000000000000009a00000000000000000000000000000000000000000000000000000000000000006a0b109cf2701798d7458ce4c437fac7b88ebde3dd6b85b910f3a78ed0deca8003ea0577b913a3c8810dd10161c9ae11e2ee31042564c62114c83b0bc5d3a3e71b362a0ef288768008cf9f330ebda83d5bf9a2eb12e41a5550668696323def06d898c17f8bc94c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2f8a5a012231cd4c753cb5530a43a74c45106c24765e6f81dc8927d4f4be7e53315d5a8a0870a24f0d51536d2dd35d875990ed507cceaa4f0cb38af85e924b9138c26b390a00ace00c6732dde49fa9b02756ef1bdfde157a7f711c5aeef3994b2b131f81b2ba011d2f51d66e456bdeab97ff67507c10fe29dddf116d972a9b7f2cb33c4674335a08dc41d5d16f80d28a2cd48949644a8dfade9434934c6b78124c238a6ea94960bf8dd94577959c519c24ee6add28ad96d3531bc6878ba34f8c6a0000000000000000000000000000000000000000000000000000000000000000aa0000000000000000000000000000000000000000000000000000000000000000ca00000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009d69443506849d7c04f9138d1a2050bbf3a0c054402ddc0f8dd9485cb0bab616fe88a89a35080516a8928f38b518bf8c6a0000000000000000000000000000000000000000000000000000000000000000ca00000000000000000000000000000000000000000000000000000000000000008a00000000000000000000000000000000000000000000000000000000000000006a00000000000000000000000000000000000000000000000000000000000000007a00000000000000000000000000000000000000000000000000000000000000009a0000000000000000000000000000000000000000000000000000000000000000a")
            tx_dict["access_list"] = {
                "chunks": bytes_to_8_bytes_chunks_little(
                    encoded
                ),
                "bytes_len": len(encoded),
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

# Returns the encoded access_list, without the first RLP prefix. This mirrors how the access of a verified transaction is handled in cairo
def encode_access_list(access_list):
    
    return encode(access_list)


## Test TX encoding:
# assert fetch_tx("0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021").hash().hex() == "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021"
# assert fetch_tx("0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51").hash().hex() == "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51"
# assert fetch_tx("0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b").hash().hex() == "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b"
# assert fetch_tx("0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b").hash().hex() == "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b"
# assert fetch_tx("0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9").hash().hex() == "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9"
