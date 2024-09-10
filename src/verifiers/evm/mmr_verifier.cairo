from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from src.types import MMRMeta
from packages.eth_essentials.lib.utils import write_felt_array_to_dict_keys
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new
from starkware.cairo.common.alloc import alloc

from packages.eth_essentials.lib.mmr import (
    mmr_root_poseidon,
    assert_mmr_size_is_valid,
    compute_peaks_positions,
)

// Validates the MMR meta, ensuring the peaks are valid and the root is correct.
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. mmr_peaks, mmr_size recreate the mmr_root
// It writes the peaks to the dict and returns the mmr_meta.
func validate_mmr_meta{
    range_check_ptr, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*
}(chain_id: felt) -> (mmr_meta: MMRMeta, dict: DictAccess*, dict_start: DictAccess*) {
    alloc_locals;

    let (local dict: DictAccess*) = default_dict_new(default_value=-1);
    tempvar dict_start = dict;

    local mmr_meta: MMRMeta;
    let (peaks: felt*) = alloc();
    local peaks_len: felt;

    %{  
        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        # Load data from inputs
        memory[ids.mmr_meta._reference_value] = mmr_batch["id"]
        memory[ids.mmr_meta._reference_value + 1] = int(mmr_batch["root"], 16)
        memory[ids.mmr_meta._reference_value + 2] = mmr_batch["size"]
        memory[ids.mmr_meta._reference_value + 3] = ids.chain_id

        ids.peaks_len = len(mmr_batch["peaks"])
        segments.write_arg(ids.peaks, hex_to_int_array(mmr_batch["peaks"]))
    %}

    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, expected_peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert 0 = peaks_len - expected_peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_poseidon(peaks, mmr_meta.size, peaks_len);
    assert 0 = mmr_meta.root - mmr_root;

    write_felt_array_to_dict_keys{dict_end=dict}(
        array=peaks, index=peaks_len - 1
    );

    return (mmr_meta=mmr_meta, dict=dict, dict_start=dict_start);
}