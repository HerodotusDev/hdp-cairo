#!venv/bin/python3
from tools.py.mmr import MMR, PoseidonHasher
from tools.make.db import fetch_block_range_from_db, create_connection
from starkware.cairo.common.poseidon_hash import poseidon_hash_many, poseidon_hash
from tools.py.utils import bytes_to_8_bytes_chunks_little, write_to_json
from dataclasses import dataclass


@dataclass
class MMRBlockInfo:
    block_number: int
    element_pos: int
    element_preimage: list[int]
    element: int


def build_mmr(block_low: int, block_high: int):
    mmr = MMR(PoseidonHasher())
    blocks = fetch_block_range_from_db(block_low, block_high, create_connection())
    blocks_info = {}
    for block in reversed(blocks):
        block_number = block[0]
        print(f"block_number: {block_number}")
        element_preimage = bytes_to_8_bytes_chunks_little(block[1])
        element = poseidon_hash_many(element_preimage)
        blocks_info[block_number] = MMRBlockInfo(
            block_number, mmr.last_pos + 1, element_preimage, element
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


if __name__ == "__main__":
    mmr, blocks_info = build_mmr(0, 99)
    cairo_input = prepare_inclusion_proofs(mmr, blocks_info)

    write_to_json("src/batch_storage_proof/storage_prover_input.json", cairo_input)
