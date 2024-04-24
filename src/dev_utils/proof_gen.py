# import os
# from tools.py.storage_proof import get_account_proof, CairoAccountMPTProof
# from trie import (
#     HexaryTrie,
# )
# import web3
# from web3 import Web3

from web3._utils.encoding import (
    pad_bytes,
)
from dataclasses import dataclass, asdict, field
import json
from tools.py.fetch_block_headers import get_block_header
from tools.py.utils import (
    bytes_to_8_bytes_chunks_little,
    split_128,
    uint256_reverse_endian,
    bytes_to_8_bytes_chunks,
)
from web3 import Web3
from eth_utils import (
    keccak,
)
import rlp
from trie import (
    HexaryTrie,
)


@dataclass
class CairoAccountMPTProof:
    address: list[int]  # Account Little endian 8 bytes chunks
    trie_key: (int, int)
    block_number: int
    proof_bytes_len: list[int]  # Number of bytes in each node in the proof
    proof: list[
        list[int]
    ]  # List of nodes in the proof, each node is a list of 8 bytes little endian chunks

    # def __repr__(self):
    #     # Custom formatting for readability
    #     return json.dumps(asdict(self), indent=4)


def int_list_to_hex_str_list(int_list):
    return [hex(x) for x in int_list]


def convert_to_hex_dict(low_high_tuple):
    low, high = low_high_tuple
    return {"low": hex(low), "high": hex(high)}


def get_account_proof(
    address: int, block_number: int, RPC_URL: str
) -> CairoAccountMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    trie_key = keccak(bytes.fromhex(hex(address)[2:]))
    block = get_block_header(block_number, RPC_URL)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [0],
        block_number,
    )

    verify_account_proof(proof.accountProof, trie_key, block.stateRoot)

    trie_key = uint256_reverse_endian(int(trie_key.hex(), 16))
    trie_key = split_128(trie_key)

    address_little = bytes_to_8_bytes_chunks_little(address.to_bytes(20, "big"))
    accountProofbytes = [node for node in proof["accountProof"]]
    accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
    accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]

    return CairoAccountMPTProof(
        address=address_little,
        trie_key=trie_key,
        block_number=block_number,
        proof_bytes_len=accountProofbytes_len,
        proof=proof,
    )


def verify_account_proof(proof, key, root):
    result = HexaryTrie.get_from_proof(root, key, format_proof_nodes(proof))

    print("Proof Valid! Result:", int(rlp.decode(result).hex(), 16))


def format_proof_nodes(proof):
    trie_proof = []
    for rlp_node in proof:
        trie_proof.append(rlp.decode(bytes(rlp_node)))
    return trie_proof


RPC_URL = "https://ethereum-rpc.publicnode.com"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

address = "0x4d6bcd482715b543aefcfc2a49963628e6c959bc"  # ERC20 https://sepolia.etherscan.io/address/0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc
block_number = 5434826
