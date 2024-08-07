from src.tasks.fetch_trait import (
    FetchTrait,
    FetchTraitBlockSampledDatalake,
    FetchTraitTransactionDatalake,
)
from starkware.cairo.common.uint256 import (
    felt_to_uint256,
    uint256_add,
    uint256_reverse_endian,
    Uint256,
)
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from starkware.cairo.common.memcpy import memcpy
from src.datalakes.block_sampled_datalake import BlockSampledProperty
from src.decoders.account_decoder import AccountDecoder
from src.decoders.header_decoder import HeaderDecoder
from src.decoders.transaction_decoder import TransactionDecoder, TransactionType
from src.decoders.receipt_decoder import ReceiptDecoder
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from src.decoders.storage_slot_decoder import StorageSlotDecoder

from contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
from contract_bootloader.contract_bootloader import run_contract_bootloader, compute_program_hash
from src.memorizer import (
    HeaderMemorizer,
    AccountMemorizer,
    StorageMemorizer,
    BlockTxMemorizer,
    BlockReceiptMemorizer,
)
from src.types import (
    BlockSampledDataLake,
    ComputationalTask,
    TransactionsInBlockDatalake,
    ChainInfo,
)
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc

func get_fetch_trait() -> FetchTrait {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let (fetch_header_data_points_ptr) = get_label_location(fetch_header_data_points);
    let (fetch_account_data_points_ptr) = get_label_location(fetch_account_data_points);
    let (fetch_storage_data_points_ptr) = get_label_location(fetch_storage_data_points);
    let (fetch_tx_data_points_ptr) = get_label_location(fetch_tx_data_points);
    let (fetch_receipt_data_points_ptr) = get_label_location(fetch_receipt_data_points);

    local block_sampled_datalake: FetchTraitBlockSampledDatalake = FetchTraitBlockSampledDatalake(
        fetch_header_data_points_ptr, fetch_account_data_points_ptr, fetch_storage_data_points_ptr
    );

    local transaction_datalake: FetchTraitTransactionDatalake = FetchTraitTransactionDatalake(
        fetch_tx_data_points_ptr, fetch_receipt_data_points_ptr
    );

    return (
        FetchTrait(
            block_sampled_datalake=&block_sampled_datalake,
            transaction_datalake=&transaction_datalake,
        )
    );
}

struct Output {
    value: Uint256,
}

func compute_slr{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(values: Uint256*, values_len: felt, predict: Uint256) -> (program_hash: felt, result: Uint256) {
    alloc_locals;

    let (local task_input_arr: felt*) = alloc();
    local values_felts: felt* = cast(values, felt*);

    assert task_input_arr[0] = values_len;
    memcpy(task_input_arr + 1, values_felts, values_len * 2 * 2);
    assert task_input_arr[1 + values_len * 2 * 2] = predict.low;
    assert task_input_arr[1 + values_len * 2 * 2 + 1] = predict.high;

    %{
        from tools.py.utils import load_json_from_package
        from contract_bootloader.contract_class.contract_class import CompiledClass
        compiled_class = CompiledClass.Schema().load(load_json_from_package("compiled_contracts/simple_linear_regression_contract.json"))
    %}

    local compiled_class: CompiledClass*;

    // Fetch contract data form hints.
    %{
        from starkware.starknet.core.os.contract_class.compiled_class_hash import create_bytecode_segment_structure
        from contract_bootloader.contract_class.compiled_class_hash_utils import get_compiled_class_struct

        bytecode_segment_structure = create_bytecode_segment_structure(
            bytecode=compiled_class.bytecode,
            bytecode_segment_lengths=compiled_class.bytecode_segment_lengths,
            visited_pcs=None,
        )

        cairo_contract = get_compiled_class_struct(
            compiled_class=compiled_class,
            bytecode=bytecode_segment_structure.bytecode_with_skipped_segments()
        )
        ids.compiled_class = segments.gen_arg(cairo_contract)
    %}

    let (builtin_costs: felt*) = alloc();
    assert builtin_costs[0] = 0;
    assert builtin_costs[1] = 0;
    assert builtin_costs[2] = 0;
    assert builtin_costs[3] = 0;
    assert builtin_costs[4] = 0;

    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length] = 0x208b7fff7fff7ffe;
    assert compiled_class.bytecode_ptr[compiled_class.bytecode_length + 1] = cast(
        builtin_costs, felt
    );

    let (local program_hash) = compiled_class_hash(compiled_class=compiled_class);

    %{ print("program_hash", hex(ids.program_hash)) %}

    %{
        vm_load_program(
            compiled_class.get_runnable_program(entrypoint_builtins=[]),
            ids.compiled_class.bytecode_ptr
        )
    %}

    let (local account_dict) = default_dict_new(default_value=7);
    let (local storage_dict) = default_dict_new(default_value=7);
    let (local header_dict) = default_dict_new(default_value=7);
    let (local block_tx_dict) = default_dict_new(default_value=7);
    let (local block_receipt_dict) = default_dict_new(default_value=7);
    local pow2_array: felt* = nondet %{ segments.add() %};

    %{
        from contract_bootloader.syscall_handler import SyscallHandler

        if '__dict_manager' not in globals():
                from starkware.cairo.common.dict import DictManager
                __dict_manager = DictManager()

        syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager)
    %}

    with account_dict, storage_dict, header_dict, block_tx_dict, block_receipt_dict, pow2_array {
        let (retdata_size, retdata) = run_contract_bootloader(
            compiled_class=compiled_class,
            calldata_size=1 + values_len * 2 * 2 + 2,
            calldata=task_input_arr,
            dry_run=0,
        );
    }

    assert retdata_size = 2;
    let result: Uint256 = Uint256(low=retdata[0], high=retdata[1]);
    return (program_hash=program_hash, result=result);
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
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    let (rlp) = AccountMemorizer.get(
        chain_id=chain_id, block_number=current_block_number, address=[datalake.properties + 1]
    );

    local data_point0: Uint256 = Uint256(low=current_block_number, high=0x0);

    let data_point1 = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(rlp=rlp, field=[datalake.properties]);  // field_idx ios always at 0

    let (data_point1_reverse_endian) = uint256_reverse_endian(data_point1);

    assert [data_points + index * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = data_point0;
    assert [data_points + index * 2 * Uint256.SIZE + 1 * Uint256.SIZE] = data_point1_reverse_endian;

    return fetch_account_data_points(
        chain_id=chain_id, datalake=datalake, index=index + 1, data_points=data_points
    );
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
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    let storage_slot = Uint256(low=[datalake.properties + 2], high=[datalake.properties + 1]);
    return fetch_storage_data_points_inner(chain_id, datalake, index, data_points, storage_slot);
}

func fetch_storage_data_points_inner{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(
    chain_id: felt,
    datalake: BlockSampledDataLake,
    index: felt,
    data_points: Uint256*,
    storage_slot: Uint256,
) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    local data_point0: Uint256 = Uint256(low=current_block_number, high=0x0);

    let (rlp) = StorageMemorizer.get(
        chain_id=chain_id,
        block_number=current_block_number,
        address=[datalake.properties],
        storage_slot=storage_slot,
    );
    let data_point1 = StorageSlotDecoder.get_word(rlp=rlp);

    let (data_point1_reverse_endian) = uint256_reverse_endian(data_point1);

    assert [data_points + index * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = data_point0;
    assert [data_points + index * 2 * Uint256.SIZE + 1 * Uint256.SIZE] = data_point1_reverse_endian;

    return fetch_storage_data_points_inner(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        data_points=data_points,
        storage_slot=storage_slot,
    );
}

// Collects the header data points defined in the datalake from the memorizer recursivly.
// Fills the data_points array with the values of the sampled property in LE
func fetch_header_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;
    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    let (rlp) = HeaderMemorizer.get(chain_id=chain_id, block_number=current_block_number);

    local data_point0: Uint256 = Uint256(low=current_block_number, high=0x0);

    let data_point1 = HeaderDecoder.get_field{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(rlp=rlp, field=[datalake.properties]);

    let (data_point1_reverse_endian) = uint256_reverse_endian(data_point1);

    assert [data_points + index * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = data_point0;
    assert [data_points + index * 2 * Uint256.SIZE + 1 * Uint256.SIZE] = data_point1_reverse_endian;

    return fetch_header_data_points(
        chain_id=chain_id, datalake=datalake, index=index + 1, data_points=data_points
    );
}

func fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_tx_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    alloc_locals;
    let current_tx_index = datalake.start_index + index * datalake.increment;
    // %{ print("current_tx_index:", ids.current_tx_index) %}

    local is_larger: felt;
    %{ ids.is_larger = 1 if ids.current_tx_index >= ids.datalake.end_index else 0 %}

    if (is_larger == 1) {
        assert [range_check_ptr] = current_tx_index - datalake.end_index;
        tempvar range_check_ptr = range_check_ptr + 1;
        return result_counter;
    }

    let (rlp) = BlockTxMemorizer.get(
        chain_id=chain_id, block_number=datalake.target_block, key_low=current_tx_index
    );

    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(rlp);

    if (datalake.included_types[tx_type] == 0) {
        return fetch_tx_data_points(
            chain_id=chain_id,
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let data_point = TransactionDecoder.get_field(
        rlp, datalake.sampled_property, rlp_start_offset, tx_type
    );
    let (data_point_reverse_endian) = uint256_reverse_endian(data_point);

    assert [data_points + result_counter * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = Uint256(
        low=current_tx_index, high=0
    );
    assert [
        data_points + result_counter * 2 * Uint256.SIZE + 1 * Uint256.SIZE
    ] = data_point_reverse_endian;

    return fetch_tx_data_points(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        result_counter=result_counter + 1,
        data_points=data_points,
    );
}

func fetch_receipt_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    alloc_locals;
    let current_receipt_index = datalake.start_index + index * datalake.increment;
    // %{ print("current_receipt_index:", ids.current_receipt_index) %}

    local is_larger: felt;
    %{ ids.is_larger = 1 if ids.current_receipt_index >= ids.datalake.end_index else 0 %}

    if (is_larger == 1) {
        assert [range_check_ptr] = current_receipt_index - datalake.end_index;
        tempvar range_check_ptr = range_check_ptr + 1;
        return result_counter;
    }

    let (rlp) = BlockReceiptMemorizer.get(
        chain_id=chain_id, block_number=datalake.target_block, key_low=current_receipt_index
    );

    let (tx_type, rlp_start_offset) = ReceiptDecoder.open_receipt_envelope(rlp);

    if (datalake.included_types[tx_type] == 0) {
        return fetch_receipt_data_points(
            chain_id=chain_id,
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let data_point = ReceiptDecoder.get_field(
        rlp, datalake.sampled_property, rlp_start_offset, tx_type, datalake.target_block
    );
    let (data_point_reverse_endian) = uint256_reverse_endian(data_point);

    assert [data_points + result_counter * 2 * Uint256.SIZE + 0 * Uint256.SIZE] = Uint256(
        low=current_receipt_index, high=0
    );
    assert [
        data_points + result_counter * 2 * Uint256.SIZE + 1 * Uint256.SIZE
    ] = data_point_reverse_endian;

    return fetch_receipt_data_points(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        result_counter=result_counter + 1,
        data_points=data_points,
    );
}
