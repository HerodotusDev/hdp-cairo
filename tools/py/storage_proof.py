from dataclasses import dataclass

from tools.py.fetch_block_headers import get_block_header
from tools.py.utils import (
    bytes_to_8_bytes_chunks_little,
    split_128,
    reverse_endian_256,
    bytes_to_8_bytes_chunks,
)
from web3 import Web3


@dataclass
class CairoAccountMPTProof:
    root: (int, int)  # Storage root in little endian Uint256
    address: list[int]  # Account Little endian 8 bytes chunks
    proof: list[
        list[int]
    ]  # List of nodes in the proof, each node is a list of 8 bytes little endian chunks
    proof_len: int  # Number of nodes in the proof
    proof_bytes_len: list[int]  # Number of bytes in each node in the proof


def get_account_proof(
    address: int, block_number: int, RPC_URL: str
) -> CairoAccountMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    block = get_block_header(block_number, RPC_URL)
    state_root = int(block.stateRoot.hex(), 16)
    state_root_little = split_128(
        int.from_bytes(state_root.to_bytes(32, "big"), "little")
    )
    address_little = bytes_to_8_bytes_chunks_little(address.to_bytes(20, "big"))
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [0],
        block_number,
    )
    accountProofbytes = [node for node in proof["accountProof"]]
    accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
    accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]

    return CairoAccountMPTProof(
        root=state_root_little,
        address=address_little,
        proof=accountProof,
        proof_len=len(accountProof),
        proof_bytes_len=accountProofbytes_len,
    )
