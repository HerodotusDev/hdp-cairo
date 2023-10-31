%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.builtin_keccak.keccak import keccak
from src.libs.mmr import compute_peaks_positions, bag_peaks
from src.libs.utils import pow2alloc127

// Test compute_peaks_positions and bag_peaks on a few MMR sizes.
// Some of the MMR sizes are randomly generated.
func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local mmr_size_0: felt;
    local mmr_size_1: felt;
    local mmr_size_2: felt;
    local mmr_size_3: felt;
    local mmr_size_4: felt;
    local mmr_size_5: felt;
    local mmr_size_6: felt;
    local mmr_size_7: felt;
    local mmr_size_8: felt;
    local mmr_size_9: felt;

    %{
        import random
        def is_valid_mmr_size(n):
            prev_peak = 0
            while n > 0:
                i = n.bit_length()
                peak = 2**i - 1
                if peak > n:
                    i -= 1
                    peak = 2**i - 1
                if peak == prev_peak:
                    return False
                prev_peak = peak
                n -= peak
            return n == 0

        ids.mmr_size_0=1
        ids.mmr_size_1=4
        ids.mmr_size_2=3
        ids.mmr_size_3=7
        ids.mmr_size_4=11
        for i in range(5, 10):
            while True:
                random_size = random.randint(0, 20000000)
                if is_valid_mmr_size(random_size):
                    setattr(ids, f"mmr_size_{i}", random_size)
                    break
    %}
    let pow2_array: felt* = pow2alloc127();

    with pow2_array {
        let n_peaks = test_peaks_positions(mmr_size_0);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_1);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_2);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_3);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_4);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_5);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_6);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_7);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_8);
        test_bag_peaks(n_peaks);
        let n_peaks = test_peaks_positions(mmr_size_9);
        test_bag_peaks(n_peaks);
    }

    return ();
}

// Computes the peaks positions for an MMR of size mmr_size, and checks that the result matches the expected positions.
// Parameters:
// - mmr_size: the size of the MMR.
// Returns:
// - The number of peaks.
func test_peaks_positions{range_check_ptr, pow2_array: felt*}(mmr_size: felt) -> felt {
    alloc_locals;
    let (true_pos: felt*) = alloc();
    local true_pos_len: felt;

    %{
        import random
        from tools.py.mmr import get_peaks

        mmr_size = ids.mmr_size
        peak_pos = [x+1 for x in get_peaks(mmr_size)] # Convert to 1-based indexing.
        segments.write_arg(ids.true_pos, peak_pos)
        ids.true_pos_len = len(peak_pos)
    %}

    let (peaks: felt*, peaks_len: felt) = compute_peaks_positions(mmr_size);
    assert 0 = peaks_len - true_pos_len;
    assert_array_rec(true_pos, peaks, peaks_len - 1);
    return peaks_len;
}

// Recursively asserts that arrays x and y are equal at all indices up to index.
func assert_array_rec(x: felt*, y: felt*, index: felt) {
    if (index == 0) {
        assert 0 = x[0] - y[0];
        return ();
    } else {
        assert 0 = x[index] - y[index];
        return assert_array_rec(x, y, index - 1);
    }
}

// Generates peaks_len random peaks values for Keccak and Poseidon, and checks that bag_peaks matches the expected.
// Parameters:
// - peaks_len: the number of peaks to generate.
func test_bag_peaks{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(peaks_len: felt) {
    alloc_locals;
    // Randomly generated peaks.
    let (peaks_poseidon: felt*) = alloc();
    let (local peaks_keccak: Uint256*) = alloc();

    // Expected bagged peaks.
    local expected_bagged_poseidon: felt;
    local expected_bagged_keccak: Uint256;

    %{
        import sha3
        import random
        from starkware.cairo.common.poseidon_hash import poseidon_hash
        p = 3618502788666131213697322783095070105623107215331596699973092056135872020481 # STARK PRIME
        n_peaks = ids.peaks_len
        def split_128(a):
            """Takes in value, returns uint256-ish tuple."""
            return [a & ((1 << 128) - 1), a >> 128]
        def bag_peaks_poseidon(peaks:list):
            bags = peaks[-1]
            for peak in reversed(peaks[:-1]):
                bags = poseidon_hash(peak, bags)
            return bags
        def bag_peaks_keccak(peaks:list):
            k = sha3.keccak_256()
            bags = peaks[-1]
            for peak in reversed(peaks[:-1]):
                k = sha3.keccak_256()
                k.update(peak.to_bytes(32, "big") + bags.to_bytes(32, "big"))
                bags = int.from_bytes(k.digest(), "big")
            return bags

        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr._reference_value+counter] = uint[0]
                memory[ptr._reference_value+counter+1] = uint[1]
                counter += 2
                
        peaks_poseidon = [random.randint(0, p-1) for _ in range(n_peaks)]
        peaks_keccak = [random.randint(0, 2**256-1) for _ in range(n_peaks)]
        peaks_keccak_split = [split_128(x) for x in peaks_keccak]

        segments.write_arg(ids.peaks_poseidon, peaks_poseidon)
        write_uint256_array(ids.peaks_keccak, peaks_keccak_split)
        ids.expected_bagged_poseidon = bag_peaks_poseidon(peaks_poseidon)
        bagged_peak_keccak_split= split_128(bag_peaks_keccak(peaks_keccak))
        ids.expected_bagged_keccak.low = bagged_peak_keccak_split[0]
        ids.expected_bagged_keccak.high = bagged_peak_keccak_split[1]
    %}

    let (bag_peaks_poseidon, bag_peaks_keccak) = bag_peaks(peaks_poseidon, peaks_keccak, peaks_len);

    assert 0 = bag_peaks_poseidon - expected_bagged_poseidon;
    assert 0 = bag_peaks_keccak.low - expected_bagged_keccak.low;
    assert 0 = bag_peaks_keccak.high - expected_bagged_keccak.high;

    return ();
}
