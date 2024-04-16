from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from src.types import MMRMeta

from packages.evm_libs_cairo.lib.mmr import (
    mmr_root_poseidon,
    assert_mmr_size_is_valid,
    compute_peaks_positions,
)

// Guard function that ensures the MMR parameters are valid
// 1. mmr_size is valid
// 2. mmr_peaks_len matches the expected value based on mmr_size
// 3. mmr_peaks, mmr_size recreate the mmr_root
// Params:
// mmr_meta: MMRMeta - the MMR metadata
// mmr_peaks: felt* - the MMR peaks
func verify_mmr_meta{range_check_ptr, poseidon_ptr: PoseidonBuiltin*, pow2_array: felt*}(
    mmr_meta: MMRMeta
) {
    alloc_locals;

    // ensure the mmr_size is valid
    assert_mmr_size_is_valid(mmr_meta.size);

    // ensure the mmr_peaks_len is valid
    let (_, peaks_len) = compute_peaks_positions(mmr_meta.size);
    assert peaks_len = mmr_meta.peaks_len;

    // ensure the mmr_peaks recreate the passed mmr_root
    let (mmr_root) = mmr_root_poseidon(mmr_meta.peaks, mmr_meta.size, mmr_meta.peaks_len);
    assert 0 = mmr_meta.root - mmr_root;

    return ();
}
