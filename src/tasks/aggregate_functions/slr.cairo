from src.tasks.fetch_trait import FetchTrait
from starkware.cairo.common.uint256 import (
    felt_to_uint256,
    uint256_add,
    uint256_reverse_endian,
    uint256_signed_div_rem,
    Uint256,
)
from starkware.cairo.common.registers import get_label_location
from packages.hdp_bootloader.bootloader.hdp_bootloader import run_simple_bootloader
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, HashBuiltin
from starkware.cairo.common.memcpy import memcpy
from src.datalakes.block_sampled_datalake import BlockSampledProperty
from src.decoders.account_decoder import AccountDecoder
from src.decoders.header_decoder import HeaderDecoder
from src.memorizer import AccountMemorizer, StorageMemorizer, HeaderMemorizer
from src.types import BlockSampledDataLake, AccountValues, ComputationalTask, Header
from starkware.cairo.common.dict_access import DictAccess

func get_fetch_trait() -> FetchTrait {
    let (fetch_header_data_points_ptr) = get_label_location(fetch_header_data_points);
    let (fetch_account_data_points_ptr) = get_label_location(fetch_account_data_points);
    let (fetch_storage_data_points_ptr) = get_label_location(fetch_storage_data_points);

    return (
        FetchTrait(
            fetch_header_data_points_ptr,
            fetch_account_data_points_ptr,
            fetch_storage_data_points_ptr,
        )
    );
}

struct Output {
    value: Uint256,
}

func compute_slr{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(values: Uint256*, values_len: felt, predict: Uint256) -> Uint256 {
    alloc_locals;

    let (local task_input_arr: felt*) = alloc();
    local values_felts: felt* = cast(values, felt*);

    assert task_input_arr[0] = values_len;
    memcpy(task_input_arr + 1, values_felts, values_len * 2 * 2);
    assert task_input_arr[1 + values_len * 2 * 2] = predict.low;
    assert task_input_arr[1 + values_len * 2 * 2 + 1] = predict.high;

    %{
        hdp_bootloader_input = {
            "task": {
                "type": "CairoSierra",
                "path": "build/compiled_cairo_files/simple_linear_regression.sierra.json",
                "use_poseidon": True
            },
            "single_page": True
        }
    %}

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

    %{ print(f"SLR prediction for {ids.predict.low} is {ids.output.value.low}") %}

    return output.value;
}

// Collects the account data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func fetch_account_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    account_dict: DictAccess*,
    account_values: AccountValues*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    let (account_value) = AccountMemorizer.get(
        address=datalake.properties + 1, block_number=current_block_number
    );

    local data_point0: Uint256 = Uint256(low=current_block_number, high=0x0);

    let data_point1 = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(rlp=account_value.values, field=[datalake.properties]);  // field_idx ios always at 0

    let (data_point1_reverse_endian) = uint256_reverse_endian(data_point1);

    assert [data_points + index * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = data_point0;
    assert [data_points + index * 2 * Uint256.SIZE + 1 * Uint256.SIZE] = data_point1_reverse_endian;

    return fetch_account_data_points(datalake=datalake, index=index + 1, data_points=data_points);
}

// Collects the storage data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func fetch_storage_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    storage_dict: DictAccess*,
    storage_values: Uint256*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    let (data_point) = StorageMemorizer.get(
        storage_slot=datalake.properties + 3,
        address=datalake.properties,
        block_number=current_block_number,
    );

    assert [data_points + index * Uint256.SIZE] = data_point;

    return fetch_storage_data_points(datalake=datalake, index=index + 1, data_points=data_points);
}

// Collects the header data points defined in the datalake from the memorizer recursivly.
// Fills the data_points array with the values of the sampled property in LE
func fetch_header_data_points{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    header_dict: DictAccess*,
    headers: Header*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;
    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    let header = HeaderMemorizer.get(block_number=current_block_number);

    let data_point = HeaderDecoder.get_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(rlp=header.rlp, field=[datalake.properties]);

    assert [data_points + index * Uint256.SIZE] = data_point;

    return fetch_header_data_points(datalake=datalake, index=index + 1, data_points=data_points);
}