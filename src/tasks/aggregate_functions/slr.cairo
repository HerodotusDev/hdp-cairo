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

    local array: felt* = cast(values, felt*);

    let (local task_input_arr: felt*) = alloc();
    local task_input_len: felt;

    // prepare prediction inputs
    %{
        offset = 0
        memory[ids.task_input_arr + offset] = ids.values_len
        offset += 1
        for i in range(ids.values_len * 2 * 2):
            memory[ids.task_input_arr + i + offset] = memory[ids.array + i]
        offset += ids.values_len * 2 * 2
    %}

    // supply prediction target
    %{
        memory[ids.task_input_arr + offset] = 10
        offset += 1
        memory[ids.task_input_arr + offset] = 0
        offset += 1
        ids.task_input_len = offset
    %}

    local return_ptr: felt*;
    %{ ids.return_ptr = segments.add() %}

    run_simple_bootloader{
        output_ptr=return_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        poseidon_ptr=poseidon_ptr,
    }(task_input_arr=task_input_arr, task_input_len=task_input_len);

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
