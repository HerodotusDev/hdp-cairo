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
from dataclasses import dataclass, asdict
import json
from tools.py.fetch_block_headers import get_block_header
from tools.py.utils import (
    bytes_to_8_bytes_chunks_little,
    split_128,
    reverse_endian_256,
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

def get_account_proof(
    address: int, block_number: int, RPC_URL: str
) -> CairoAccountMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    trie_key =  keccak(bytes.fromhex(hex(address)[2:]))
    block = get_block_header(block_number, RPC_URL)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [0],
        block_number,
    )

    verify_account_proof(proof.accountProof, trie_key, block.stateRoot)

    trie_key = reverse_endian_256(int(trie_key.hex(), 16))
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
        proof=accountProof,
    )

def get_slot_proof(
    address: int, block_number: int, RPC_URL: str, slot: str
) -> CairoAccountMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    trie_key =  keccak(bytes.fromhex(slot[2:]))
    block = get_block_header(block_number, RPC_URL)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [int(slot, 16)],
        block_number,
    )

    verify_account_proof(proof.storageProof[0].proof, trie_key, proof.storageHash)

    trie_key = reverse_endian_256(int(trie_key.hex(), 16))
    trie_key = split_128(trie_key)

    address_little = bytes_to_8_bytes_chunks_little(bytes.fromhex(slot[2:]))
    accountProofbytes = [node for node in proof.storageProof[0].proof]
    accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
    accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]
    print("Account Slot Proof:", accountProof)
    return CairoAccountMPTProof(
        address=address_little,
        trie_key=trie_key,
        block_number=block_number,
        proof_bytes_len=accountProofbytes_len,
        proof=accountProof,
    )
# ):

def verify_account_proof(proof, key, root):
    result = HexaryTrie.get_from_proof(
        root, key, format_proof_nodes(proof)
    )

    print("Proof Valid! Result:", result.hex())



def format_proof_nodes(proof):
    trie_proof = []
    for rlp_node in proof:
        trie_proof.append(rlp.decode(bytes(rlp_node)))
    return trie_proof


    
RPC_URL = "https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

address = 0x439c5305DA2548DBC3a04bb4B3d22322701B1cA8
# address = 0xd3CdA913deB6f67967B99D67aCDFa1712C293601
block_number = 10529663
proof=get_slot_proof(address, block_number, RPC_URL, "0x0000000000000000000000000000000000000000000000000000000000000000")
# proof=get_account_proof(address, block_number, RPC_URL)