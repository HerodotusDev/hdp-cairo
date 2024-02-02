from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.libs.utils import get_felt_bitlength

// Asserts that the MMR size is valid given:
// - our condition on size (1 <= x <= 2^126)
// - the specific way the MMR is constructed, ie : a list of balanced merkle trees.
// For example,
// 0 is not a valid MMR size.
// 1 is a valid MMR size.
// 2 is not a valid MMR size.
// 3 is a valid MMR size.
// 4 is a valid MMR size.
// 5 is not a valid MMR size.
// 6 is not a valid MMR size.
// 7 is a valid MMR size.
// 8 is a valid MMR size.
// 9 is not a valid MMR size.
// 10 is a valid MMR size.
// etc.
// Params:
// - x: felt - MMR size.
// Fails if the MMR size is not valid given the above conditions.
func assert_mmr_size_is_valid{range_check_ptr, pow2_array: felt*}(x: felt) {
    assert [range_check_ptr] = x;
    assert [range_check_ptr + 1] = 2 ** 126 - x;
    tempvar range_check_ptr = range_check_ptr + 2;
    if (x == 0) {
        assert 1 = 0;  // Add an unsatisfiable assertion to make sure the program fails.
        return ();
    } else {
        let is_valid = is_valid_mmr_size_inner(x, 0);
        assert is_valid - 1 = 0;
        return ();
    }
}
// Inner function for assert_mmr_size_is_valid.
// Contains the core logic for MMR size validation.
// Parameters:
// Should not be called directly.
// Implicits arguments:
// - pow2_array: felt* - Array of powers of 2.
// Params:
// - n: felt - remaining size that hasn't been associated with a peak.
// - prev_peak: felt - size of the last identified peak
func is_valid_mmr_size_inner{range_check_ptr, pow2_array: felt*}(n: felt, prev_peak: felt) -> felt {
    alloc_locals;
    let is_n_sup_equal_1 = is_le(1, n);
    if (is_n_sup_equal_1 == 0) {
        if (n == 0) {
            return 1;
        } else {
            return 0;
        }
    } else {
        let i = get_felt_bitlength(n);
        let peak_tmp = pow2_array[i] - 1;
        let is_peak_sup_n = is_le(n + 1, peak_tmp);

        local peak;  // Max (2^k - 1) value such that 2^(k-1) <= n
        if (is_peak_sup_n != 0) {
            assert peak = pow2_array[i - 1] - 1;
        } else {
            assert peak = peak_tmp;
        }
        if (peak == prev_peak) {
            return 0;
        } else {
            return is_valid_mmr_size_inner(n=n - peak, prev_peak=peak);
        }
    }
}

// Determines the height of the MMR tree based on a given index x.
// Assumes the starting index is 1 as depicted:
// H    MMR positions
// 2        7
//        /   \
// 1     3     6
//      / \   / \
// 0   1   2 4   5
// Reference: https://github.com/mimblewimble/grin/blob/0ff6763ee64e5a14e70ddd4642b99789a1648a32/core/src/core/pmmr.rs#L606
// Implicits arguments:
// - pow2_array: felt* - Array holding powers of 2 values.
// Params:
// - x: felt - Index (or position) in the MMR.
// Assumptions for the caller:
// 1 <= x < 2^127
// Returns:
// - height: felt - Calculated height for the specified position.
func compute_height_pre_alloc_pow2{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        x = ids.x
        ids.bit_length = x.bit_length()
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits

    tempvar N = pow2_array[bit_length];
    tempvar n = pow2_array[bit_length - 1];

    if (x == N - 1) {
        // x has bit_length bits and they are all ones.
        // We return the height which is bit_length - 1.
        // %{ print(f" compute_height : {ids.bit_length - 1} ") %}
        assert [range_check_ptr] = bit_length;
        assert [range_check_ptr + 1] = 127 - bit_length;
        tempvar range_check_ptr = range_check_ptr + 2;
        return bit_length - 1;
    } else {
        // Ensure 2^(bit_length-1) <= x < 2^bit_length so that x has indeed bit_length bits.
        assert [range_check_ptr] = bit_length;
        assert [range_check_ptr + 1] = 127 - bit_length;
        assert [range_check_ptr + 2] = N - x - 1;
        assert [range_check_ptr + 3] = x - n;
        tempvar range_check_ptr = range_check_ptr + 4;
        // Jump left on the MMR and continue until it's all ones.
        // This is done by substracting (2^(bit_length-1) - 1) from x.
        return compute_height_pre_alloc_pow2(x - n + 1);
    }
}

// Computes the leftmost peak's position in the MMR based on its size.
// Reference: https://docs.grin.mw/wiki/chain-state/merkle-mountain-range/#hashing-and-bagging
// Implicits arguments:
// - pow2_array: felt* - Array of powers of 2.
// Params:
// - mmr_len: felt - MMR size.
// Assumptions:
// - 1 <= mmr_len < 2^127
// Returns:
// - peak_pos: felt - Position of the leftmost peak.
func compute_first_peak_pos{range_check_ptr, pow2_array: felt*}(mmr_len: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        mmr_len = ids.mmr_len
        ids.bit_length = mmr_len.bit_length()
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits

    let N = pow2_array[bit_length];
    let n = pow2_array[bit_length - 1];

    assert [range_check_ptr] = bit_length;
    assert [range_check_ptr + 1] = 127 - bit_length;
    assert [range_check_ptr + 2] = N - mmr_len - 1;
    assert [range_check_ptr + 3] = mmr_len - n;

    tempvar range_check_ptr = range_check_ptr + 4;

    let all_ones = pow2_array[bit_length] - 1;
    if (mmr_len == all_ones) {
        return mmr_len;
    } else {
        let peak_pos = pow2_array[bit_length - 1] - 1;
        return peak_pos;
    }
}

// Retrieves positions of MMR peaks from left to right and their count based on the MMR size.
// Reference: https://docs.grin.mw/wiki/chain-state/merkle-mountain-range/#hashing-and-bagging
// Implicits arguments:
// - pow2_array: felt* - Array of powers of 2.
// Params:
// - mmr_len: felt - Size of the MMR. Must be a validated MMR size. (see assert_mmr_size_is_valid function)
// Assumptions:
// - 1 <= mmr_len < 2^127
// - mmr_len is a valid MMR size. See validate_mmr_size function.
// Returns:
// - peaks: felt* - Pointer to the peaks' position array.
// - peaks_len: felt - Number of peaks.
func compute_peaks_positions{range_check_ptr, pow2_array: felt*}(mmr_len: felt) -> (
    peaks: felt*, peaks_len: felt
) {
    alloc_locals;
    let (peaks: felt*) = alloc();
    with mmr_len {
        let first_peak_pos = compute_first_peak_pos(mmr_len);
        assert peaks[0] = first_peak_pos;
        let peaks_len = compute_peaks_inner(peaks=peaks, peaks_len=1, mmr_pos=first_peak_pos);
    }

    return (peaks, peaks_len);
}

// Inner function for compute_peaks_positions.
// Should not be called directly, but only within compute_peaks_positions with its requirements satisfied. with its assumptions satisfied.
// Implicits arguments:
// - pow2_array: felt* - Array of powers of 2.
// - mmr_len: felt - Size of the MMR.
// Params:
// - peaks: felt* - Pointer to array storing peak positions. First peak at index 0 is already set.
// - peaks_len: felt - Initial number of peaks (set to 1 initially).
// - mmr_pos: felt - Current MMR position. The function concludes when mmr_pos matches mmr_len.
// Returns:
// - peaks_len: felt - Final count of peaks.
func compute_peaks_inner{range_check_ptr, pow2_array: felt*, mmr_len: felt}(
    peaks: felt*, peaks_len: felt, mmr_pos: felt
) -> felt {
    alloc_locals;
    if (mmr_pos == mmr_len) {
        return peaks_len;
    } else {
        let height = compute_height_pre_alloc_pow2(mmr_pos);
        let right_sibling = mmr_pos + pow2_array[height + 1] - 1;  // Same height as mmr_pos
        let left_child = left_child_jump_until_inside_mmr(right_sibling, height);
        assert peaks[peaks_len] = left_child;
        return compute_peaks_inner(peaks, peaks_len + 1, left_child);
    }
}

// Inner function for compute_peaks_inner.
// Should not be called directly, but only within compute_peaks_inner with its requirements satisfied.
// Iterates to the left child from a position until reaching within the MMR bounds.
// Reference: https://docs.grin.mw/wiki/chain-state/merkle-mountain-range/#hashing-and-bagging
// Implicits arguments:
// - pow2_array: Array of powers of 2.
// - mmr_len: Size of the MMR. Must be a validated MMR size. (see assert_mmr_size_is_valid function)
// Params:
// - left_child: felt - Current left child position.
// - height: felt - height of the current left child.
// Returns:
// - left_child: felt - First left child's position within the MMR.
func left_child_jump_until_inside_mmr{range_check_ptr, pow2_array: felt*, mmr_len: felt}(
    left_child: felt, height: felt
) -> felt {
    alloc_locals;
    local in_mmr;

    %{ ids.in_mmr = 1 if ids.left_child<=ids.mmr_len else 0 %}
    if (in_mmr != 0) {
        // Ensure left_child <= mmr_len
        assert [range_check_ptr] = mmr_len - left_child;
        tempvar range_check_ptr = range_check_ptr + 1;
        return left_child;
    } else {
        // Ensure mmr_len < left_child
        assert [range_check_ptr] = left_child - mmr_len - 1;
        tempvar range_check_ptr = range_check_ptr + 1;

        let left_child = left_child - pow2_array[height];
        return left_child_jump_until_inside_mmr(left_child, height - 1);
    }
}

// Returns the value of peaks for both MMRs at a given position
// The values are taken either from the MMR array or from the previous peaks dictionary depending on the position
// Implicits arguments:
// - mmr_array_poseidon: array of new nodes of the Poseidon MMR
// - mmr_array_keccak: array of new nodes of the Keccak MMR
// - mmr_offset: offset of the MMR (previous MMR length). Must be a validated MMR size. (see assert_mmr_size_is_valid function)
// - previous_peaks_dict_poseidon: dictionary of previous peaks for Poseidon
// - previous_peaks_dict_keccak: dictionary of previous peaks for Keccak
// Params:
// - position: felt - position in the MMR. Must be a correct left or right child position to be merged in the current MMR state.
// Returns:
// - peak_poseidon: felt - value of the peak for Poseidon
// - peak_keccak: Uint256 - value of the peak for Keccak
// This function should only be called when merging left and right chidrens, or when merging peaks.
// This is ensured in the main program's logic inside the merge_subtrees_if_applicable function.
// If the asked position is not in the MMR array, it is necessarily a previous peak and therefore present in the previous peaks dictionary
// Otherwise, if the asked position is <= mmr_offset, and position!=peak position, it will return the default value of the dict which is 0.
func get_full_mmr_peak_values{
    range_check_ptr,
    mmr_array_poseidon: felt*,
    mmr_array_keccak: Uint256*,
    mmr_offset: felt,
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
}(position: felt) -> (peak_poseidon: felt, peak_keccak: Uint256) {
    alloc_locals;
    // %{ print(f"Asked position : {ids.position}, mmr_offset : {ids.mmr_offset}") %}
    local is_position_in_mmr_array: felt;
    %{ ids.is_position_in_mmr_array= 1 if ids.position > ids.mmr_offset else 0 %}
    if (is_position_in_mmr_array != 0) {
        // %{ print(f'getting from mmr_array at index {ids.position-ids.mmr_offset -1}') %}
        // ensure position > mmr_offset
        let mmr_array_position = position - mmr_offset - 1;
        assert [range_check_ptr] = mmr_array_position;
        tempvar range_check_ptr = range_check_ptr + 1;
        let peak_poseidon = mmr_array_poseidon[mmr_array_position];
        let peak_keccak = mmr_array_keccak[mmr_array_position];
        // %{
        //     print(f"mmr_array poseidon value at {ids.position - ids.mmr_offset -1} = {ids.peak_poseidon}")
        //     print(f"mmr_array keccak value at {ids.position - ids.mmr_offset -1 } = {ids.peak_keccak.low} {ids.peak_keccak.high}")
        // %}
        return (peak_poseidon, peak_keccak);
    } else {
        // %{ print('getting from dict') %}
        // ensure position <= mmr_offset
        assert [range_check_ptr] = mmr_offset - position;
        tempvar range_check_ptr = range_check_ptr + 1;
        let (peak_poseidon: felt) = dict_read{dict_ptr=previous_peaks_dict_poseidon}(key=position);
        // Treat the felt value from dict back to a Uint256 ptr:
        let (peak_keccak_ptr: Uint256*) = dict_read{dict_ptr=previous_peaks_dict_keccak}(
            key=position
        );
        local peak_keccak: Uint256;
        assert peak_keccak.low = peak_keccak_ptr.low;
        assert peak_keccak.high = peak_keccak_ptr.high;
        // %{
        //     print(f"dict_peak poseidon value at {ids.position} = {ids.peak_poseidon}")
        //     print(f"dict_peak keccak value at {ids.position} = {ids.peak_keccak.low} {ids.peak_keccak.high}")
        // %}
        return (peak_poseidon, peak_keccak);
    }
}

// Compute the roots of both MMRs by bagging their peaks (see bag peaks function)
// Hashes to bagged peaks with the size of the MMR: root=H(mmr_size, bagged_peak)
// Implicits arguments:
// - mmr_array_poseidon: felt* - array of new nodes of the Poseidon MMR
// - mmr_array_keccak: Uint256* - array of new nodes of the Keccak MMR
// - mmr_array_len: felt - length of the MMR array.
// - pow2_array: felt* - array of powers of 2
// - previous_peaks_dict_poseidon: DictAccess* - dictionary of previous peaks for Poseidon MMR.
// - mmr_offset: offset of the MMR (size of the previous MMR).
// Requirements for the caller:
// Both dicts must be initialized with previous peaks at the correct positions.
// mmr_array_len must be positive >= 1
// mmr_offset must be a validated MMR size. (see assert_mmr_size_is_valid function)
// mmr_array+mmr_offset must be a validated MMR size. (see assert_mmr_size_is_valid function)
// - previous_peaks_dict_keccak: DictAccess* - dictionary of previous peaks for Keccak MMR
// Returns:
// - root_poseidon: felt - root of the Poseidon MMR
// - root_keccak: Uint256 - root of the Keccak MMR
func get_roots{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    mmr_array_poseidon: felt*,
    mmr_array_keccak: Uint256*,
    mmr_array_len: felt,
    pow2_array: felt*,
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
    mmr_offset: felt,
}() -> (root_poseidon: felt, root_keccak: Uint256) {
    alloc_locals;
    let mmr_size = mmr_offset + mmr_array_len;
    let (peaks_positions: felt*, peaks_len: felt) = compute_peaks_positions(mmr_size);
    let (peaks_poseidon: felt*, peaks_keccak: Uint256*) = get_peaks_from_positions{
        peaks_positions=peaks_positions
    }(peaks_len);
    let (bagged_peaks_poseidon, bagged_peaks_keccak) = bag_peaks(
        peaks_poseidon, peaks_keccak, peaks_len
    );

    let (root_poseidon) = poseidon_hash(mmr_size, bagged_peaks_poseidon);

    let (keccak_input: felt*) = alloc();
    let inputs_start = keccak_input;
    keccak_add_uint256{inputs=keccak_input}(num=Uint256(mmr_size, 0), bigend=1);
    keccak_add_uint256{inputs=keccak_input}(num=bagged_peaks_keccak, bigend=1);
    let (root_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
    let (root_keccak) = uint256_reverse_endian(root_keccak);

    return (root_poseidon, root_keccak);
}

// Returns the peaks values from left to right for both MMRs given the peaks positions
// Should only be called within the get_roots function with its requirements satisfied.
// Implicits arguments:
// - mmr_array_poseidon: felt* - array of new nodes of the Poseidon MMR
// - mmr_array_keccak: Uint256* - array of new nodes of the Keccak MMR
// - mmr_offset: felt - offset of the MMR (previous MMR length)
// - previous_peaks_dict_poseidon: DictAccess* - dictionary of previous peaks for Poseidon MMR
// - previous_peaks_dict_keccak: DictAccess* - dictionary of previous peaks for Keccak MMR
// - peaks_positions: felt* - array of positions of the peaks
// Params:
// - peaks_len: felt - length of the peaks_positions array.
// Returns:
// - peaks_poseidon: felt* - array of peaks values for Poseidon MMR
// - peaks_keccak: Uint256* - array of peaks values for Keccak MMR
func get_peaks_from_positions{
    range_check_ptr,
    mmr_array_poseidon: felt*,
    mmr_array_keccak: Uint256*,
    mmr_offset: felt,
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
    peaks_positions: felt*,
}(peaks_len: felt) -> (peaks_poseidon: felt*, peaks_keccak: Uint256*) {
    alloc_locals;
    let (peaks_poseidon: felt*) = alloc();
    let (peaks_keccak: Uint256*) = alloc();
    get_peaks_from_positions_inner(peaks_poseidon, peaks_keccak, peaks_len - 1);
    return (peaks_poseidon, peaks_keccak);
}

// Inner function for get_peaks_from_positions. Should only be called within get_peaks_from_positions with its requirements satisfied.
// Implicits arguments:
// - mmr_array_poseidon: felt* - array of new nodes of the Poseidon MMR
// - mmr_array_keccak: Uint256* - array of new nodes of the Keccak MMR
// - mmr_offset: felt - offset of the MMR (previous MMR length)
// - previous_peaks_dict_poseidon: DictAccess* - dictionary of previous peaks for Poseidon MMR
// - previous_peaks_dict_keccak: DictAccess* - dictionary of previous peaks for Keccak MMR
// - peaks_positions: felt* - array of positions of the peaks
// Params:
// - peaks_poseidon: felt* - array of peaks values for Poseidon MMR (to be filled)
// - peaks_keccak: Uint256* - array of peaks values for Keccak MMR (to be filled)
// - index: felt - index of the peak to be retrieved
func get_peaks_from_positions_inner{
    range_check_ptr,
    mmr_array_poseidon: felt*,
    mmr_array_keccak: Uint256*,
    mmr_offset: felt,
    previous_peaks_dict_poseidon: DictAccess*,
    previous_peaks_dict_keccak: DictAccess*,
    peaks_positions: felt*,
}(peaks_poseidon: felt*, peaks_keccak: Uint256*, index: felt) {
    alloc_locals;
    if (index == 0) {
        let (value_poseidon: felt, value_keccak: Uint256) = get_full_mmr_peak_values(
            peaks_positions[0]
        );
        assert peaks_poseidon[0] = value_poseidon;
        assert peaks_keccak[0].low = value_keccak.low;
        assert peaks_keccak[0].high = value_keccak.high;

        return ();
    } else {
        let (value_poseidon, value_keccak) = get_full_mmr_peak_values(peaks_positions[index]);
        assert peaks_poseidon[index] = value_poseidon;
        assert peaks_keccak[index].low = value_keccak.low;
        assert peaks_keccak[index].high = value_keccak.high;
        return get_peaks_from_positions_inner(peaks_poseidon, peaks_keccak, index - 1);
    }
}

// Hashes the peaks of both MMRs together by computing H(peak1, H(peak2, H(peak3, ...))).
// peak1 is the leftmost peak, peakN is the rightmost peak.
// Params:
// - peaks_poseidon: the peaks of the MMR to hash together
// - peaks_keccak: the peaks of the MMR to hash together
// - peaks_len: the number of peaks to hash together
// Returns:
// - bag_peaks_poseidon: Poseidon(peak1, Poseidon(peak2, Poseidon(peak3, ...)))
// - bag_peaks_keccak: Keccak(peak1, Keccak(peak2, Keccak(peak3, ...)))
func bag_peaks{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(peaks_poseidon: felt*, peaks_keccak: Uint256*, peaks_len: felt) -> (
    bag_peaks_poseidon: felt, bag_peaks_keccak: Uint256
) {
    alloc_locals;

    assert_le(1, peaks_len);
    if (peaks_len == 1) {
        return ([peaks_poseidon], [peaks_keccak]);
    }

    let last_peak_poseidon = [peaks_poseidon];
    let last_peak_keccak = [peaks_keccak];
    let (rec_poseidon, rec_keccak) = bag_peaks(peaks_poseidon + 1, peaks_keccak + 2, peaks_len - 1);

    let (res_poseidon) = poseidon_hash(last_peak_poseidon, rec_poseidon);
    let (keccak_input: felt*) = alloc();
    let inputs_start = keccak_input;
    keccak_add_uint256{inputs=keccak_input}(num=last_peak_keccak, bigend=1);
    keccak_add_uint256{inputs=keccak_input}(num=rec_keccak, bigend=1);
    let (res_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
    let (res_keccak) = uint256_reverse_endian(res_keccak);
    return (res_poseidon, res_keccak);
}

// Hashes the peaks of both MMRs together by computing H(peak1, H(peak2, H(peak3, ...))).
// peak1 is the leftmost peak, peakN is the rightmost peak.
// Params:
// - peaks_poseidon: the peaks of the MMR to hash together
// - peaks_len: the number of peaks to hash together
// Returns:
// - bag_peaks_poseidon: Poseidon(peak1, Poseidon(peak2, Poseidon(peak3, ...)))
func bag_peaks_poseidon{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
}(peaks_poseidon: felt*, peaks_len: felt) -> (
    bag_peaks_poseidon: felt
) {
    alloc_locals;

    let current_peak = [peaks_poseidon];

    assert_le(1, peaks_len);
    if (peaks_len == 1) {
        return (current_peak, );
    }

    let (rec_poseidon) = bag_peaks_poseidon(peaks_poseidon + 1, peaks_len - 1);
    let (res_poseidon) = poseidon_hash(current_peak, rec_poseidon);

    return (bag_peaks_poseidon=res_poseidon);
}

func mmr_root_poseidon{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
} (peaks_poseidon: felt*, mmr_size: felt, peaks_len: felt) -> (
    mmr_root: felt
) {
    let (bag_peak) = bag_peaks_poseidon(peaks_poseidon, peaks_len);
    let (root) = poseidon_hash(mmr_size, bag_peak);
    return (mmr_root=root);
}

func hash_mmr_inclusion_proof{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
}(
    element: felt,
    height: felt,
    position: felt,
    inclusion_proof: felt*,
    inclusion_proof_len: felt,
) -> (peak: felt) {
    alloc_locals;
    if (inclusion_proof_len == 0) {
        return (peak=element);
    } 
    
    let position_height = compute_height_pre_alloc_pow2(position);
    let next_height = compute_height_pre_alloc_pow2(position + 1);
    // %{ print(f"position {ids.position}, h={ids.position_height}, nh={ids.next_height}") %}
    if (next_height == position_height + 1) {
        // We are in a right child
        // %{ print(f"hashing right : {memory[ids.inclusion_proof + ids.inclusion_proof_index]}, {ids.element}") %}

        let (element) = poseidon_hash([inclusion_proof], element);
        return hash_mmr_inclusion_proof(
            element,
            height + 1,
            position + 1,
            inclusion_proof= inclusion_proof + 1,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    } else {
        // We are in a left child
        // %{ print(f"hashing left : {ids.element}, {memory[ids.inclusion_proof + ids.inclusion_proof_index]}") %}
        let (element) = poseidon_hash(element, [inclusion_proof]);
        tempvar element = element;
        tempvar position = position + pow2_array[height + 1];
        return hash_mmr_inclusion_proof(
            element,
            height + 1,
            position,
            inclusion_proof= inclusion_proof + 1,
            inclusion_proof_len=inclusion_proof_len - 1,
        );
    }
}