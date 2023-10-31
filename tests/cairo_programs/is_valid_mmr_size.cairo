%builtins range_check

from starkware.cairo.common.alloc import alloc

from src.libs.mmr import is_valid_mmr_size_inner
from src.libs.utils import pow2alloc127

func main{range_check_ptr}() {
    alloc_locals;
    %{ print('\n') %}
    test_is_valid_mmr_size_with_mmr_creation(num_elems=256);
    test_is_valid_mmr_size_random_sizes(num_sizes=100);
    return ();
}
func is_valid_mmr_size{range_check_ptr, pow2_array: felt*}(x: felt) -> felt {
    assert [range_check_ptr] = x;
    assert [range_check_ptr + 1] = 2 ** 126 - x;
    tempvar range_check_ptr = range_check_ptr + 2;
    if (x == 0) {
        return 0;
    }
    return is_valid_mmr_size_inner(x, 0);
}
func test_is_valid_mmr_size_with_mmr_creation{range_check_ptr}(num_elems: felt) {
    alloc_locals;
    let (expected_output: felt*) = alloc();
    let (input_array: felt*) = alloc();
    let pow2_array: felt* = pow2alloc127();
    %{
        print(f"Testing is_valid_mmr_size by creating the mmr for all sizes in [0, {ids.num_elems})...")
        from tools.py.mmr import MMR
        mmr = MMR()
        valid_mmr_sizes =set()
        for i in range(ids.num_elems):
            mmr.add(i)
            valid_mmr_sizes.add(len(mmr.pos_hash))

        expected_output = [size in valid_mmr_sizes for size in range(0, len(mmr.pos_hash) + 1)]
        segments.write_arg(ids.expected_output, expected_output)
        segments.write_arg(ids.input_array, list(range(0, len(mmr.pos_hash) + 1)))
    %}
    let (actual_output: felt*) = alloc();
    with pow2_array {
        output_is_valid_mmr_size_array(actual_output, input_array, 0, num_elems);
    }

    assert_array_rec(expected_output, actual_output, 0, num_elems);
    %{ print(f"\tPass!\n\n") %}
    return ();
}

func test_is_valid_mmr_size_random_sizes{range_check_ptr}(num_sizes: felt) {
    alloc_locals;
    let (input_array: felt*) = alloc();
    let (expected_output: felt*) = alloc();
    let pow2_array: felt* = pow2alloc127();
    %{
        from tools.py.mmr import is_valid_mmr_size
        import random
        print(f"Testing is_valid_mmr_size against python implementation with {ids.num_sizes} random sizes in [0, 20000000)...")
        sizes_to_test = random.sample(range(0, 20000000), ids.num_sizes)
        expected_output = [is_valid_mmr_size(size) for size in sizes_to_test]
        segments.write_arg(ids.expected_output, expected_output)
        segments.write_arg(ids.input_array, sizes_to_test)
    %}
    let (actual_output: felt*) = alloc();
    with pow2_array {
        output_is_valid_mmr_size_array(actual_output, input_array, 0, num_sizes);
    }

    assert_array_rec(expected_output, actual_output, 0, num_sizes);
    %{ print(f"\tPass!\n\n") %}

    return ();
}

// Build output_array[i] = is_valid_mmr_size(input_array[i]) for all i in [0, max).
func output_is_valid_mmr_size_array{range_check_ptr, pow2_array: felt*}(
    output_array: felt*, input_array: felt*, index: felt, max: felt
) {
    if (index == max) {
        return ();
    } else {
        let is_valid = is_valid_mmr_size(input_array[index]);
        assert output_array[index] = is_valid;
        return output_is_valid_mmr_size_array(output_array, input_array, index + 1, max);
    }
}
// Assert x[i] = y[i] for all i in [index, end).
func assert_array_rec(x: felt*, y: felt*, index: felt, end: felt) {
    alloc_locals;
    if (index == end) {
        return ();
    } else {
        assert 0 = x[index] - y[index];
        return assert_array_rec(x, y, index + 1, end);
    }
}
