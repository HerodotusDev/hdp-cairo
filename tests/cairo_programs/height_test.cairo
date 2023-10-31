%builtins range_check

from starkware.cairo.common.alloc import alloc

from src.libs.mmr import compute_height_pre_alloc_pow2
from src.libs.utils import pow2alloc127

// Tests compute_height_pre_alloc_pow2(pos) for pos in [min_pos, max_pos].
func main{range_check_ptr}() {
    alloc_locals;
    test_compute_height(min_pos=1, max_pos=1024);
    return ();
}

// Asserts compute_height_pre_alloc_pow2(pos) == tree_pos_height(pos - 1) for pos in [min_pos, max_pos].
// Arguments:
// * min_pos - The minimum position to test.
// * max_pos - The maximum position to test.
func test_compute_height{range_check_ptr}(min_pos: felt, max_pos: felt) {
    alloc_locals;
    let (expected_heights: felt*) = alloc();
    let (positions: felt*) = alloc();
    local n_positions;
    %{
        from tools.py.mmr import tree_pos_height
        import random
        min_pos = ids.min_pos
        max_pos = ids.max_pos

        assert 1 <= min_pos < max_pos
        pos_1_based_index = [x for x in range(min_pos, max_pos+1)]
        # Convert to 0-based index because tree_pos_height(pos) expects 0-based index, 
        # although compute_height_pre_alloc_pow2(pos) expects 1-based index.
        pos_0_based_index = [x - 1 for x in pos_1_based_index]

        expected_heights = [tree_pos_height(x) for x in pos_0_based_index]
        segments.write_arg(ids.expected_heights, expected_heights)
        segments.write_arg(ids.positions, pos_1_based_index)

        ids.n_positions = max_pos - min_pos + 1
    %}

    let pow2_array: felt* = pow2alloc127();

    with pow2_array {
        assert_height_recursive(
            index=n_positions - 1, expected_heights=expected_heights, positions=positions
        );
    }
    return ();
}
// Asserts compute_height_pre_alloc_pow2(positions[index]) == expected_heights[index] for index in [0, n_positions -1].
// Arguments:
// * index - The index of the position in positions and expected_heights.
// * expected_heights - Pointer to an array of expected heights.
// * positions - Pointer to an array of positions.
func assert_height_recursive{range_check_ptr, pow2_array: felt*}(
    index: felt, expected_heights: felt*, positions: felt*
) {
    alloc_locals;
    if (index == 0) {
        let h = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(positions[0]);

        assert h = expected_heights[0];
        return ();
    }

    let h = compute_height_pre_alloc_pow2{pow2_array=pow2_array}(positions[index]);

    assert 0 = h - expected_heights[index];

    assert_height_recursive(index - 1, expected_heights, positions);
    return ();
}
