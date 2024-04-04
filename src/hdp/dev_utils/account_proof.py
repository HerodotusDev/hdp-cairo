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
    trie_key: tuple[int, int]
    proofs: list[dict] = field(default_factory=list)

    def to_dict(self):
        return {
            "address": int_list_to_hex_str_list(self.address),
            "trie_key": convert_to_hex_dict(self.trie_key),
            "proofs": [
                {
                    "block_number": proof["block_number"],
                    "proof_bytes_len": proof["proof_bytes_len"],
                    "proof": [
                        int_list_to_hex_str_list(node) for node in proof["proof"]
                    ],
                }
                for proof in self.proofs
            ],
        }


def export_to_json(instance):
    instance_dict = instance.to_dict()
    json_str = json.dumps(instance_dict, indent=4)
    return json_str


def int_list_to_hex_str_list(int_list):
    return [hex(x) for x in int_list]


def convert_to_hex_dict(low_high_tuple):
    low, high = low_high_tuple
    return {"low": hex(low), "high": hex(high)}


def get_account_proof(
    address: str, block_number: int, RPC_URL: str
) -> CairoAccountMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    trie_key = keccak(bytes.fromhex(address[2:]))
    block = get_block_header(block_number, RPC_URL)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [0],
        block_number,
    )

    verify_account_proof(proof.accountProof, trie_key, block.stateRoot)

    trie_key = uint256_reverse_endian(int(trie_key.hex(), 16))
    trie_key = split_128(trie_key)

    address_little = bytes_to_8_bytes_chunks_little(bytes.fromhex(address[2:]))
    accountProofbytes = [node for node in proof["accountProof"]]
    accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
    accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]

    proofObj = [
        {
            "block_number": block_number,
            "proof_bytes_len": accountProofbytes_len,
            "proof": accountProof,
        }
    ]

    return CairoAccountMPTProof(
        address=address_little,
        trie_key=trie_key,
        proofs=proofObj,
    )


def verify_account_proof(proof, key, root):
    result = HexaryTrie.get_from_proof(root, key, format_proof_nodes(proof))

    print("Proof Valid! Result:", rlp.decode(result))


def format_proof_nodes(proof):
    trie_proof = []
    for rlp_node in proof:
        trie_proof.append(rlp.decode(bytes(rlp_node)))
    return trie_proof


RPC_URL = "https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

address = "0x779877A7B0D9E8603169DdbD7836e478b4624789"  # ERC20 https://sepolia.etherscan.io/address/0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc
block_number = 5415971

proof = get_account_proof(address, block_number, RPC_URL)
print(export_to_json(proof))
