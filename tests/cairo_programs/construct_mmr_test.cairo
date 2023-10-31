// %builtins output range_check bitwise keccak poseidon
// Builtins are commented because of redefinition when importing functions from src.single_chunk_processor.chunk_processor
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256

from src.libs.mmr import (
    compute_height_pre_alloc_pow2,
    compute_first_peak_pos,
    compute_peaks_positions,
    bag_peaks,
    get_roots,
)
from src.libs.utils import pow2alloc127
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash

from src.single_chunk_processor.chunk_processor import construct_mmr, initialize_peaks_dicts

// Simulates MMR construction based on a previous MMR.
// See hint for more details.
func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    // Values filled from the hint :

    // - Random elements to be appended to the new MMR. Simulates the hashes of block headers.
    let (poseidon_hash_array: felt*) = alloc();
    let (keccak_hash_array: Uint256*) = alloc();

    local n_values_to_append;  // The number of elements in poseidon_hash_array and keccak_hash_array.

    local mmr_offset;  // The size of the previous MMR.

    // - The values of the previous peaks.

    let (previous_peaks_values_poseidon: felt*) = alloc();
    let (previous_peaks_values_keccak: Uint256*) = alloc();

    // - The root of the previous MMR.
    local mmr_last_root_poseidon: felt;
    local mmr_last_root_keccak: Uint256;

    // - The expected root of the new MMR.
    local expected_new_root_poseidon: felt;
    local expected_new_root_keccak: Uint256;

    // - The expected length of the new MMR.
    local expected_new_len: felt;

    %{
        import random
        from tools.py.mmr import get_peaks, MMR, PoseidonHasher, KeccakHasher
        STARK_PRIME = 3618502788666131213697322783095070105623107215331596699973092056135872020481

        def split_128(a):
            """Takes in value, returns uint256-ish tuple."""
            return [a & ((1 << 128) - 1), a >> 128]
        def from_uint256(a):
            """Takes in uint256-ish tuple, returns value."""
            return a[0] + (a[1] << 128)
        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr._reference_value+counter] = uint[0]
                memory[ptr._reference_value+counter+1] = uint[1]
                counter += 2

        previous_n_values= random.randint(1, 200)
        n_values_to_append=random.randint(1, 200)
        ids.n_values_to_append=n_values_to_append;

        # Initialize random values to be appended to the new MMR.
        poseidon_hash_array = [random.randint(0, STARK_PRIME-1) for _ in range(n_values_to_append)]
        keccak_hash_array = [split_128(random.randint(0, 2**256-1)) for _ in range(n_values_to_append)]
        segments.write_arg(ids.poseidon_hash_array, poseidon_hash_array)
        write_uint256_array(ids.keccak_hash_array, keccak_hash_array)


        # Initialize MMR objects
        mmr_poseidon = MMR(PoseidonHasher())
        mmr_keccak = MMR(KeccakHasher())

        # Initialize previous values
        previous_values_poseidon = [random.randint(0, STARK_PRIME-1) for _ in range(previous_n_values)]
        previous_values_keccak = [random.randint(0, 2**256-1) for _ in range(previous_n_values)]

        # Fill MMRs with previous values
        for elem in previous_values_poseidon:
           _= mmr_poseidon.add(elem)
        for elem in previous_values_keccak:
           _= mmr_keccak.add(elem)

        # Write the previous MMR size to the Cairo memory.
        ids.mmr_offset=len(mmr_poseidon.pos_hash)

        # Get the previous peaks and write them to the Cairo memory.
        previous_peaks_poseidon = [mmr_poseidon.pos_hash[peak_position] for peak_position in get_peaks(len(mmr_poseidon.pos_hash))]
        previous_peaks_keccak = [split_128(mmr_keccak.pos_hash[peak_position]) for peak_position in get_peaks(len(mmr_keccak.pos_hash))]
        segments.write_arg(ids.previous_peaks_values_poseidon, previous_peaks_poseidon)
        write_uint256_array(ids.previous_peaks_values_keccak, previous_peaks_keccak)

        # Write the previous MMR root to the Cairo memory.
        ids.mmr_last_root_poseidon = mmr_poseidon.get_root()
        ids.mmr_last_root_keccak.low, ids.mmr_last_root_keccak.high = split_128(mmr_keccak.get_root())

        # Fill MMRs with new values, in reversed order to match the Cairo code. (construct_mmr() appends the values starting from the last index of the array)
        for new_elem in reversed(poseidon_hash_array):
            _= mmr_poseidon.add(new_elem)
        for new_elem in reversed(keccak_hash_array):
            _= mmr_keccak.add(from_uint256(new_elem))

        # Write the expected new MMR roots and length to the Cairo memory.
        ids.expected_new_root_poseidon = mmr_poseidon.get_root()
        ids.expected_new_root_keccak.low, ids.expected_new_root_keccak.high = split_128(mmr_keccak.get_root())
        ids.expected_new_len = len(mmr_poseidon.pos_hash)
    %}

    let pow2_array: felt* = pow2alloc127();

    let (
        previous_peaks_positions: felt*, previous_peaks_positions_len: felt
    ) = compute_peaks_positions{pow2_array=pow2_array}(mmr_offset);

    let (bagged_peaks_poseidon, bagged_peaks_keccak) = bag_peaks(
        previous_peaks_values_poseidon, previous_peaks_values_keccak, previous_peaks_positions_len
    );

    let (root_poseidon) = poseidon_hash(mmr_offset, bagged_peaks_poseidon);

    let (keccak_input: felt*) = alloc();
    let inputs_start = keccak_input;
    keccak_add_uint256{inputs=keccak_input}(num=Uint256(mmr_offset, 0), bigend=1);
    keccak_add_uint256{inputs=keccak_input}(num=bagged_peaks_keccak, bigend=1);
    let (root_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
    let (root_keccak) = uint256_reverse_endian(root_keccak);

    // Check that the previous roots matche the ones provided in the program's input:
    assert 0 = root_poseidon - mmr_last_root_poseidon;
    assert 0 = root_keccak.low - mmr_last_root_keccak.low;
    assert 0 = root_keccak.high - mmr_last_root_keccak.high;

    //
    let (local previous_peaks_dict_poseidon) = default_dict_new(default_value=0);
    let (local previous_peaks_dict_keccak) = default_dict_new(default_value=0);
    tempvar dict_start_poseidon = previous_peaks_dict_poseidon;
    tempvar dict_start_keccak = previous_peaks_dict_keccak;
    initialize_peaks_dicts{
        dict_end_poseidon=previous_peaks_dict_poseidon, dict_end_keccak=previous_peaks_dict_keccak
    }(
        previous_peaks_positions_len - 1,
        previous_peaks_positions,
        previous_peaks_values_poseidon,
        previous_peaks_values_keccak,
    );

    // Intialize MMR arrays. Those will be filled by the construct_mmr function.
    let (mmr_array_poseidon: felt*) = alloc();
    let (mmr_array_keccak: Uint256*) = alloc();
    // Length is common to both arrays.
    let mmr_array_len = 0;

    with poseidon_hash_array, keccak_hash_array, mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, mmr_offset, previous_peaks_dict_poseidon, previous_peaks_dict_keccak {
        construct_mmr(index=n_values_to_append - 1);
    }
    with mmr_array_poseidon, mmr_array_keccak, mmr_array_len, pow2_array, previous_peaks_dict_poseidon, previous_peaks_dict_keccak, mmr_offset {
        let (new_mmr_root_poseidon: felt, new_mmr_root_keccak: Uint256) = get_roots();
    }

    // Assert the new MMR root and length are as expected.
    assert mmr_array_len + mmr_offset - expected_new_len = 0;

    assert new_mmr_root_poseidon - expected_new_root_poseidon = 0;
    assert new_mmr_root_keccak.low - expected_new_root_keccak.low = 0;
    assert new_mmr_root_keccak.high - expected_new_root_keccak.high = 0;

    // Finalize dicts for soundness.
    default_dict_finalize(dict_start_poseidon, previous_peaks_dict_poseidon, 0);
    default_dict_finalize(dict_start_keccak, previous_peaks_dict_keccak, 0);

    return ();
}
