import web3
from web3 import Web3
from eth_utils import (
    keccak,
)
import rlp
from rlp.codec import consume_length_prefix
from rlp.sedes import (
    Binary,
    big_endian_int,
)
from trie import (
    HexaryTrie,
)
from web3._utils.encoding import (
    pad_bytes,
)
from tools.py.utils import (
    find_subsequence_metadata,
    find_byte_subsequence,
    bytes_to_8_bytes_chunks,
    bytes_to_8_bytes_chunks_little,
)
from trie.utils.nodes import (
    decode_node,
    get_node_type,
    extract_key,
    compute_leaf_key,
    compute_extension_key,
    is_blank_node,
    is_extension_node,
    is_leaf_node,
    consume_common_prefix,
    key_starts_with,
)

from trie.utils.nibbles import bytes_to_nibbles

import pickle

offline = False

RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/3QG7M_ZxG-uvZrfVE6y824aEvT67QdTr"

zero = 0x0000000000000000000000000000000000000000000000000000000000000000
w3 = Web3(Web3.HTTPProvider(RPC_URL))


def format_proof_nodes(proof):
    trie_proof = []
    for rlp_node in proof:
        trie_proof.append(rlp.decode(bytes(rlp_node)))
    return trie_proof


def verify_eth_get_proof(proof, root):
    trie_root = Binary.fixed_length(32, allow_empty=True)
    hash32 = Binary.fixed_length(32)

    class _Account(rlp.Serializable):
        fields = [
            ("nonce", big_endian_int),
            ("balance", big_endian_int),
            ("storage", trie_root),
            ("code_hash", hash32),
        ]

    acc = _Account(proof.nonce, proof.balance, proof.storageHash, proof.codeHash)
    print(acc)
    rlp_account = rlp.encode(acc)
    trie_key = keccak(bytes.fromhex(proof.address[2:]))
    print(f"trie_key: {trie_key.hex()}")
    assert rlp_account == HexaryTrie.get_from_proof(
        root, trie_key, format_proof_nodes(proof.accountProof)
    ), f"Failed to verify account proof {proof.address}"

    for storage_proof in proof.storageProof:
        trie_key = keccak(pad_bytes(b"\x00", 32, storage_proof.key))
        root = proof.storageHash
        if storage_proof.value == b"\x00":
            rlp_value = b""
        else:
            rlp_value = rlp.encode(storage_proof.value)

        assert rlp_value == HexaryTrie.get_from_proof(
            root, trie_key, format_proof_nodes(storage_proof.proof)
        ), f"Failed to verify storage proof {storage_proof.key}"

    return True


address = 0xD3CDA913DEB6F67967B99D67ACDFA1712C293601
trie_key = keccak(bytes.fromhex(hex(address)[2:]))


if not offline:
    block = w3.eth.get_block(81326)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(hex(address)),
        [zero],
        81326,
    )
    assert verify_eth_get_proof(proof, block.stateRoot)
    ap = proof.accountProof
    pickle.dump(ap, open("account_proof.ap", "wb"))


elif offline:
    ap = pickle.load(open("account_proof.ap", "rb"))


consume_length_prefix(ap[0], 0)
consume_length_prefix(ap[1], 0)
consume_length_prefix(ap[2], 0)
consume_length_prefix(ap[3], 0)
consume_length_prefix(ap[4], 0)


def extract_n_bytes_from_word(word, pos, n):
    """
    Extracts n bytes from a 64-bit word starting at position pos.

    :param word: 64-bit word as an integer.
    :param pos: Position to start extraction (0-indexed).
    :param n: Number of bytes to extract.
    :return: Extracted bytes as an integer.
    """
    # Mask to extract the desired bytes
    mask = (1 << (n * 8)) - 1

    # Shift the word right to align the desired bytes at the end, then apply the mask
    extracted_bytes = (word >> (pos * 8)) & mask

    return extracted_bytes


# Example
word = int.from_bytes([0xB7, 0xB6, 0xB5, 0xB4, 0xB3, 0xB2, 0xB1, 0xB0], byteorder="big")
pos = 1
n = 2
extracted = extract_n_bytes_from_word(word, pos, n)
extracted


def merge_integers_to_bytes(int_array):
    # Initialize an empty byte array
    merged_bytes = bytearray()
    # Process all integers except the last one
    for number in int_array[:-1]:
        # Convert each integer to a byte array of fixed 8 bytes and append
        merged_bytes.extend(number.to_bytes(8, "big"))
    # Process the last integer
    if int_array:
        last_number = int_array[-1]
        num_bytes = (last_number.bit_length() + 7) // 8  # Minimum bytes needed
        merged_bytes.extend(last_number.to_bytes(num_bytes, "big"))
    return bytes(merged_bytes)


def extract_n_bytes_from_array(
    bytes_array, start_word, start_offset, n_bytes_to_extract
):
    start_byte = start_word * 8 + start_offset
    end_byte = start_byte + n_bytes_to_extract
    res_bytes = bytes_array[start_byte:end_byte]
    return res_bytes
