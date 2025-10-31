from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from src.types import MMRMetaPoseidon, MMRMetaKeccak
from packages.eth_essentials.lib.utils import (
    write_felt_array_to_dict_keys,
    write_uint256_array_to_dict_keys,
)
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.alloc import alloc
from packages.eth_essentials.lib.mmr import (
    mmr_root_poseidon,
    mmr_root_keccak,
    assert_mmr_size_is_valid,
    compute_peaks_positions,
)
from starkware.cairo.common.uint256 import Uint256

// Validates the MMR meta, ensuring the peaks are valid and the root is correct.
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. mmr_peaks, mmr_size recreate the mmr_root
// It writes the peaks to the dict and returns the mmr_meta.
func validate_poseidon_mmr_meta{range_check_ptr, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*}(
    mmr_meta: MMRMetaPoseidon*, peaks: felt*, peaks_len: felt
) -> (dict: DictAccess*, dict_start: DictAccess*) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=0);
    tempvar dict_start = dict;

    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_poseidon(peaks, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root - mmr_root;

    write_felt_array_to_dict_keys{dict_end=dict}(array=peaks, index=peaks_len - 1);

    return (dict=dict, dict_start=dict_start);
}

// Validates the MMR meta, ensuring the peaks are valid and the root is correct.
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. mmr_peaks, mmr_size recreate the mmr_root
// It writes the peaks to the dict and returns the mmr_meta.
func validate_keccak_mmr_meta{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: felt*,
    pow2_array: felt*,
}(mmr_meta: MMRMetaKeccak*, peaks: Uint256*, peaks_len: felt) -> (
    dict: DictAccess*, dict_start: DictAccess*
) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=0);
    tempvar dict_start = dict;

    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_keccak(peaks, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root_low - mmr_root.low;
    assert 0 = mmr_meta.root_high - mmr_root.high;

    write_uint256_array_to_dict_keys{dict_end=dict}(array=peaks, index=peaks_len - 1);

    return (dict=dict, dict_start=dict_start);
}
