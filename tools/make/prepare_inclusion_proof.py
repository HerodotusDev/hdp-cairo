#!venv/bin/python3
from tools.py.mmr import MMR, PoseidonHasher
from tools.make.db import fetch_block_range_from_db, create_connection
from starkware.cairo.common.poseidon_hash import poseidon_hash_many, poseidon_hash
from tools.py.utils import bytes_to_8_bytes_chunks_little, write_to_json
from dataclasses import dataclass
from tools.py.utils import rpc_request
from dotenv import load_dotenv
import os
import time

# from web3._utils.proof import verify_eth_getProof, storage_position

STATE_ROOT_TRIE_TYPE = 0
RECEIPTS_ROOT_TRIE_TYPE = 1
WITHDRAWAL_ROOT_TRIE_TYPE = 2
load_dotenv()
RPC_URL = os.getenv("RPC_URL_MAINNET")

SAMPLE_ACCOUNT = "0xAF26F7C6BF453E2078F08953E4B28004A2C1E209"
BYTE_STATE_ROOT_START_IDX = 91
BYTE_STATE_ROOT_END_IDX = 123


@dataclass
class MMRBlockInfo:
    block_number: int
    element_pos: int
    element_preimage: list[int]
    element: int
    state_root: int


def build_mmr(block_low: int, block_high: int):
    mmr = MMR(PoseidonHasher())
    blocks = fetch_block_range_from_db(block_low, block_high, create_connection())
    blocks_info = {}
    for block in reversed(blocks):
        block_number = block[0]
        print(f"block_number: {block_number}")
        element_preimage = bytes_to_8_bytes_chunks_little(block[1])
        element = poseidon_hash_many(element_preimage)
        state_root = int.from_bytes(
            block[1][BYTE_STATE_ROOT_START_IDX:BYTE_STATE_ROOT_END_IDX], "big"
        )
        blocks_info[block_number] = MMRBlockInfo(
            block_number, mmr.last_pos + 1, element_preimage, element, state_root
        )

        mmr.add(element)
    return mmr, blocks_info


def prepare_inclusion_proofs(mmr: MMR, blocks_info: dict[int, MMRBlockInfo]) -> dict:
    root = mmr.get_root()
    cairo_input = {"mmr_root": root, "mmr_size": mmr.last_pos + 1}
    inclusion_proofs = []
    element_preimages = []
    element_positions = []

    for n, block_info in blocks_info.items():
        # print(n, block_info.element_pos + 1)
        proof = mmr.gen_proof(block_info.element_pos)
        proof.verify(root, block_info.element_pos, block_info.element)

        inclusion_proofs.append(proof.proof)
        element_preimages.append(block_info.element_preimage)
        element_positions.append(
            block_info.element_pos + 1
        )  # Convert to 1-based indexing

    cairo_input["inclusion_proofs"] = inclusion_proofs
    cairo_input["element_preimages"] = element_preimages
    cairo_input["element_positions"] = element_positions

    return cairo_input


def prepare_storage_proofs(blocks_info: dict[int, MMRBlockInfo]):
    trie_types = []
    for block_number, block_info in blocks_info.items():
        trie_types.append(STATE_ROOT_TRIE_TYPE)
        param = {
            "jsonrpc": "2.0",
            "method": "eth_getProof",
            "params": [
                SAMPLE_ACCOUNT,
                ["0x0000000000000000000000000000000000000000000000000000000000000000"],
                hex(block_number),
            ],
            "id": 1,
        }
        rr = rpc_request(RPC_URL, param)
        accountproof = rr["result"]["accountProof"]
        print(len(accountproof))
        time.sleep(0.3)

    return trie_types


if __name__ == "__main__":
    mmr, blocks_info = build_mmr(0, 10)
    cairo_input = prepare_inclusion_proofs(mmr, blocks_info)
    trie_types = prepare_storage_proofs(blocks_info)
    cairo_input["trie_types"] = trie_types
    write_to_json("src/batch_storage_proof/storage_prover_input.json", cairo_input)
