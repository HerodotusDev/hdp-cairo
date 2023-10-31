INPUT_PATH = "src/single_chunk_processor/data/"
FILENAME_DOT_CAIRO = "chunk_processor.cairo"
FILENAME = FILENAME_DOT_CAIRO.removesuffix(".cairo")
FILENAME_DOT_CAIRO_PATH = "src/single_chunk_processor/chunk_processor.cairo"
COMPILED_CAIRO_FILE_PATH = f"build/compiled_cairo_files/{FILENAME}.json"

STARK_PRIME = (
    3618502788666131213697322783095070105623107215331596699973092056135872020481
)
CAIROUT_OUTPUT_KEYS = [
    "from_block_number_high",
    "to_block_number_low",
    "block_n_plus_one_parent_hash_low",
    "block_n_plus_one_parent_hash_high",
    "block_n_minus_r_plus_one_parent_hash_low",
    "block_n_minus_r_plus_one_parent_hash_high",
    "mmr_last_root_poseidon",
    "mmr_last_root_keccak_low",
    "mmr_last_root_keccak_high",
    "mmr_last_len",
    "new_mmr_root_poseidon",
    "new_mmr_root_keccak_low",
    "new_mmr_root_keccak_high",
    "new_mmr_len",
]

MAX_RESOURCES_PER_JOB = {
    "n_steps": 2**24,
    "builtin_instance_counter": {  # 2**24 is the maximum number of steps per job
        "range_check_builtin": 1048576,
        "bitwise_builtin": 262144,
        "keccak_builtin": 8192,
        "poseidon_builtin": 524288,
    },
}
