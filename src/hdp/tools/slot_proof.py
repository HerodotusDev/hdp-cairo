from web3._utils.encoding import (
    pad_bytes,
)
from dataclasses import dataclass, asdict, field
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

def int_list_to_hex_str_list(int_list):
    return [hex(x) for x in int_list]

def convert_to_hex_dict(low_high_tuple):
    low, high = low_high_tuple
    return {"low": hex(low), "high": hex(high)}

@dataclass
class CairoSlotMPTProof:
    address: list[int]
    slot: list[int]
    storage_key: tuple[int, int]
    proofs: list[dict] = field(default_factory=list)

    def to_dict(self):
        return {
            "address": int_list_to_hex_str_list(self.address),
            "slot": int_list_to_hex_str_list(self.slot),
            "storage_key": convert_to_hex_dict(self.storage_key),
            "proofs": [{
                "block_number": proof["block_number"],
                "proof_bytes_len": proof["proof_bytes_len"],
                "proof": [int_list_to_hex_str_list(node) for node in proof["proof"]],
            } for proof in self.proofs]
        }  # List of nodes in the proof, each node is a list of 8 bytes little endian chunks

def export_to_json(instance):
    instance_dict = instance.to_dict()
    json_str = json.dumps(instance_dict, indent=4)
    return json_str


def get_slot_proof(
    address: str, block_number: int, RPC_URL: str, slot: str
) -> CairoSlotMPTProof:
    w3 = Web3(Web3.HTTPProvider(RPC_URL))

    storage_key =  keccak(bytes.fromhex(slot[2:]))
    block = get_block_header(block_number, RPC_URL)
    proof = w3.eth.get_proof(
        w3.toChecksumAddress(address),
        [int(slot, 16)],
        block_number,
    )

    verify_account_proof(proof.storageProof[0].proof, storage_key, proof.storageHash)

    storage_key = reverse_endian_256(int(storage_key.hex(), 16))
    storage_key = split_128(storage_key)
    address_little = bytes_to_8_bytes_chunks_little(bytes.fromhex(address[2:]))
    slot_little = bytes_to_8_bytes_chunks_little(bytes.fromhex(slot[2:]))
    slotProofbytes = [node for node in proof.storageProof[0].proof]
    slotProofbytes_len = [len(byte_proof) for byte_proof in slotProofbytes]
    slotProof = [bytes_to_8_bytes_chunks_little(node) for node in slotProofbytes]

    proofObj = [{
        "block_number": block_number,
        "proof_bytes_len": slotProofbytes_len,
        "proof": slotProof,
    }]
    return CairoSlotMPTProof(
        address=address_little,
        slot=slot_little,
        storage_key=storage_key,
        proofs=proofObj,
    )

def verify_account_proof(proof, key, root):
    result = HexaryTrie.get_from_proof(
        root, key, format_proof_nodes(proof)
    )

    print("Proof Valid! Result:", int(rlp.decode(result).hex(), 16))

def format_proof_nodes(proof):
    trie_proof = []
    for rlp_node in proof:
        trie_proof.append(rlp.decode(bytes(rlp_node)))
    return trie_proof

    
RPC_URL = "https://sepolia.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

address = "0x4d6bcd482715b543aefcfc2a49963628e6c959bc" # ERC20 https://sepolia.etherscan.io/address/0x4D6bCD482715B543aEfcfC2A49963628E6c959Bc
block_number = 5434826


def gen_invalid_slot_example():
    proof = get_slot_proof(
        address, 
        block_number, 
        RPC_URL, 
        "0x8b6320060189e975d5109fc49da096d04d476f43cc21351b6eae9d24bf2aa304" # _balanceOf for 0x345696b3A0DB63784EE59Bae1dA95758ff615bc5
    )
    print("\nCairo Inputs:")
    print(export_to_json(proof))


def gen_valid_slot_example():
    proof = get_slot_proof(
        address, 
        block_number, 
        RPC_URL, 
        "0xe034d5bf282edc41d85f4f6f7c3fa6366d65546fd9c5c73ccfa943e88e6ea9a6" # _balanceOf for 0xe2Aafbf1889087C1383E43625AF7433D4fad9824
    )

    print("\nCairo Inputs:")
    print(export_to_json(proof))

gen_invalid_slot_example()
# gen_valid_slot_example()