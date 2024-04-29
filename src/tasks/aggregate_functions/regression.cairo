from src.tasks.aggregate_functions.sum import compute_sum
from starkware.cairo.common.uint256 import (
    Uint256,
    felt_to_uint256,
    uint256_signed_div_rem,
    uint256_add,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

struct Output {
    result: felt,
}

func compute_regression{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    values: Uint256*, values_len: felt
) -> Uint256 {
    alloc_locals;

    // Inputs
    local input = values;
    local input_size = values_len * 2;

    // TODO call run_simple_bootloader fake output_ptr

    let output = cast(output - Output.SIZE, Output*);

    return (output.result);
}
