from src.tasks.aggregate_functions.sum import compute_sum
from starkware.cairo.common.uint256 import (
    Uint256,
    felt_to_uint256,
    uint256_signed_div_rem,
    uint256_add,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, HashBuiltin
from packages.hdp_bootloader.bootloader.hdp_bootloader import run_simple_bootloader

struct Fixed {
    mag: felt,
    sign: felt,
}

struct Output {
    prediction: Fixed,
}

func compute_slr{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(values: Uint256*, values_len: felt) -> Uint256 {
    alloc_locals;

    let (local task_input_arr: felt*) = alloc();

    assert task_input_arr[0] = values_len;
    memcpy(task_input_arr + 1, cast(values, felt*), values_len * 2 * 2);

    assert task_input_arr[1 + values_len * 2 * 2] = 10;
    assert task_input_arr[1 + values_len * 2 * 2 + 1] = 0;

    local return_ptr: felt*;
    %{ ids.return_ptr = segments.add() %}

    run_simple_bootloader{
        output_ptr=return_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        poseidon_ptr=poseidon_ptr,
    }(task_input_arr=task_input_arr, task_input_len=1 + values_len * 2 * 2 + 2);

    let output = cast(return_ptr - Output.SIZE, Output*);

    local hash: felt;

    %{
        from starkware.cairo.lang.vm.crypto import poseidon_hash_many
        ids.hash = poseidon_hash_many([
            ids.output.prediction.mag,
            ids.output.prediction.sign,
        ])
    %}

    return (Uint256(low=hash, high=0));
}
