from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from src.types import MMRMeta, MMRMetaKeccak
from packages.eth_essentials.lib.utils import write_felt_array_to_dict_keys
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
func validate_mmr_meta_evm{range_check_ptr, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*}(
    ) -> (mmr_meta: MMRMeta, dict: DictAccess*, dict_start: DictAccess*) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=-1);
    tempvar dict_start = dict;

    local mmr_meta: MMRMeta = MMRMeta(
        id=nondet %{ header_with_mmr_evm.mmr_meta.id %},
        root=nondet %{ header_with_mmr_evm.mmr_meta.root %},
        size=nondet %{ header_with_mmr_evm.mmr_meta.size %},
        chain_id=nondet %{ header_with_mmr_evm.mmr_meta.chain_id %},
    );

    tempvar peaks_len: felt = nondet %{ len(header_with_mmr_evm.mmr_meta.peaks) %};

    let (peaks: felt*) = alloc();
    %{ segments.write_arg(ids.peaks, header_with_mmr_evm.mmr_meta.peaks) %}

    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_poseidon(peaks, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root - mmr_root;

    write_felt_array_to_dict_keys{dict_end=dict}(array=peaks, index=peaks_len - 1);

    return (mmr_meta=mmr_meta, dict=dict, dict_start=dict_start);
}

// Validates the MMR meta, ensuring the peaks are valid and the root is correct.
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. mmr_peaks, mmr_size recreate the mmr_root
// It writes the peaks to the dict and returns the mmr_meta.
func validate_mmr_meta_starknet{range_check_ptr, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*}(
    ) -> (mmr_meta: MMRMeta, dict: DictAccess*, dict_start: DictAccess*) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=-1);
    tempvar dict_start = dict;

    local mmr_meta: MMRMeta = MMRMeta(
        id=nondet %{ header_with_mmr_starknet.mmr_meta.id %},
        root=nondet %{ header_with_mmr_starknet.mmr_meta.root %},
        size=nondet %{ header_with_mmr_starknet.mmr_meta.size %},
        chain_id=nondet %{ header_with_mmr_starknet.mmr_meta.chain_id %},
    );

    tempvar peaks_len: felt = nondet %{ len(header_with_mmr_starknet.mmr_meta.peaks) %};

    let (peaks: felt*) = alloc();
    %{ segments.write_arg(ids.peaks, header_with_mmr_starknet.mmr_meta.peaks) %}

    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_poseidon(peaks, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root - mmr_root;

    write_felt_array_to_dict_keys{dict_end=dict}(array=peaks, index=peaks_len - 1);

    return (mmr_meta=mmr_meta, dict=dict, dict_start=dict_start);
}


// Keccak-based MMR meta validation for EVM.
// Validates the MMR meta (keccak variant), ensuring:
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. keccak mmr_peaks, mmr_size recreate the keccak mmr_root (Uint256)
// It returns the keccak mmr_meta and empty dict placeholders for symmetry.
func validate_mmr_meta_evm_keccak{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: felt*, pow2_array: felt*}(
    ) -> (mmr_meta: MMRMetaKeccak, dict: DictAccess*, dict_start: DictAccess*) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=-1);
    tempvar dict_start = dict;

    // Build keccak MMR meta from scope
    local mmr_meta: MMRMetaKeccak = MMRMetaKeccak(
            id=nondet %{ header_with_mmr_evm.mmr_meta.id %},
            root_low=nondet %{ int.from_bytes(bytes(header_with_mmr_evm.mmr_meta.root), 'big') & ((1 << 128) - 1) %},
            root_high=nondet %{ int.from_bytes(bytes(header_with_mmr_evm.mmr_meta.root), 'big') >> 128 %},
            size=nondet %{ header_with_mmr_evm.mmr_meta.size %},
            chain_id=nondet %{ header_with_mmr_evm.mmr_meta.chain_id %},
    );

    // Load peaks (Uint256) from scope
    tempvar peaks_len: felt = nondet %{ len(header_with_mmr_evm.mmr_meta.peaks) %};
    let (peaks_keccak: Uint256*) = alloc();
    %{ segments.write_arg(ids.peaks_keccak, header_with_mmr_evm.mmr_meta.peaks) %}

    // Validate size and peaks length
    assert_mmr_size_is_valid(mmr_meta.size);
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // Recompute keccak MMR root and compare
    let (root) = mmr_root_keccak(peaks_keccak, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root_low - root.low;
    assert 0 = mmr_meta.root_high - root.high;


    return (mmr_meta=mmr_meta, dict=dict, dict_start=dict_start);
}
