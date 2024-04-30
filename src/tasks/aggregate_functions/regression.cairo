from src.tasks.aggregate_functions.sum import compute_sum
from starkware.cairo.common.uint256 import (
    Uint256,
    felt_to_uint256,
    uint256_signed_div_rem,
    uint256_add,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, HashBuiltin
from packages.hdp_bootloader.bootloader.hdp_bootloader import run_simple_bootloader

struct Output {
    result: Uint256,
}

func compute_regression{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(values: Uint256*, values_len: felt) -> Uint256 {
    alloc_locals;

    // Inputs
    local task_input_arr: felt* = cast(values, felt*);
    local task_input_len = values_len * 2;

    local return_ptr: felt*;
    %{ ids.return_ptr = segments.add() %}

    %{ simple_bootloader_input = {} %}

    run_simple_bootloader{
        output_ptr=return_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        poseidon_ptr=poseidon_ptr,
    }(task_input_arr=task_input_arr, task_input_len=task_input_len);

    let output = cast(return_ptr - Output.SIZE, Output*);

    return (output.result);
}
