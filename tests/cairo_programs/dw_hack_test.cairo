%builtins range_check

from src.libs.utils import pow2alloc127

// A small test to play with define word arrays and their indexes using the pow2alloc127 function.
// The goal is to demonstrate that the prover can access any memory location if the index of a define word array that comes from a hint is not checked.
func main{range_check_ptr}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc127();

    // compute_height_pre_alloc_pow2_hack0{pow2_array=pow2_array}(17);  // Wrong value access
    // compute_height_pre_alloc_pow2_hack1{pow2_array=pow2_array}(17);  // Inifinte loop when running
    // compute_height_pre_alloc_pow2_hack2{pow2_array=pow2_array}(17);  // Out of memory access

    // The prover is basically able to access any memory location with the bit_length index.
    // Can he find a offset so that he gets two consecutive memory locations that makes the range checks pass?
    // The fact that we are writing to memory N then n, and not n then N (in the same order as the pow2_array), should protect us from this attack.
    // The goal is to avoid two RC asserting 0 < bit_length <= 127.
    return ();
}

// Modified version of the compute_height_pre_alloc_pow2 with bit_length = 140.
func compute_height_pre_alloc_pow2_hack0{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        x = ids.x
        ids.bit_length = 140
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits

    tempvar N = pow2_array[bit_length];
    tempvar protect_malicious_prover = -1;
    tempvar n = pow2_array[bit_length - 1];

    %{ print("N", ids.N, "n", ids.n) %}

    if (x == N - 1) {
        // x has bit_length bits and they are all ones.
        // We return the height which is bit_length - 1.
        return bit_length - 1;
    } else {
        // Ensure 2^(bit_length-1) <= x < 2^bit_length so that x has indeed bit_length bits.
        assert [range_check_ptr] = N - x - 1;
        assert [range_check_ptr + 1] = x - n;
        tempvar range_check_ptr = range_check_ptr + 2;
        // Jump left on the MMR and continue until it's all ones.
        return compute_height_pre_alloc_pow2_hack0(x - n + 1);
    }
}

// Modified version of the compute_height_pre_alloc_pow2 with bit_length = -1.
func compute_height_pre_alloc_pow2_hack1{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        x = ids.x
        ids.bit_length = -1
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits

    let N = pow2_array[bit_length];
    tempvar protect_malicious_prover = -1;
    let n = pow2_array[bit_length - 1];

    %{ print("N", ids.N, "n", ids.n) %}

    if (x == N - 1) {
        // x has bit_length bits and they are all ones.
        // We return the height which is bit_length - 1.
        return bit_length - 1;
    } else {
        // Ensure 2^(bit_length-1) <= x < 2^bit_length so that x has indeed bit_length bits.
        assert [range_check_ptr] = N - x - 1;
        assert [range_check_ptr + 1] = x - n;
        tempvar range_check_ptr = range_check_ptr + 2;
        // Jump left on the MMR and continue until it's all ones.
        return compute_height_pre_alloc_pow2_hack1(x - n + 1);
    }
}

// Modified version of the compute_height_pre_alloc_pow2 with bit_length = 2500.
func compute_height_pre_alloc_pow2_hack2{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    alloc_locals;
    local bit_length;
    %{
        x = ids.x
        ids.bit_length = 2500
    %}
    // Computes N=2^bit_length and n=2^(bit_length-1)
    // x is supposed to verify n = 2^(b-1) <= x < N = 2^bit_length <=> x has bit_length bits

    let N = pow2_array[bit_length];
    tempvar protect_malicious_prover = -1;
    let n = pow2_array[bit_length - 1];

    %{ print("N", ids.N, "n", ids.n) %}

    if (x == N - 1) {
        // x has bit_length bits and they are all ones.
        // We return the height which is bit_length - 1.
        return bit_length - 1;
    } else {
        // Ensure 2^(bit_length-1) <= x < 2^bit_length so that x has indeed bit_length bits.
        assert [range_check_ptr] = N - x - 1;
        assert [range_check_ptr + 1] = x - n;
        tempvar range_check_ptr = range_check_ptr + 2;
        // Jump left on the MMR and continue until it's all ones.
        return compute_height_pre_alloc_pow2_hack2(x - n + 1);
    }
}
