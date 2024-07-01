from starkware.cairo.common.cairo_builtins import (
    PoseidonBuiltin,
    BitwiseBuiltin,
    HashBuiltin,
    KeccakBuiltin,
)
from starkware.cairo.common.uint256 import Uint256, felt_to_uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from src.datalakes.datalake import Datalake, get_default_fetch_trait
from src.types import BlockSampledDataLake, ComputationalTask, Header, ChainInfo
from src.tasks.aggregate_functions.sum import compute_sum
from src.tasks.aggregate_functions.avg import compute_avg
from src.tasks.aggregate_functions.min_max import uint256_min_le, uint256_max_le
from src.tasks.aggregate_functions.count_if import count_if
from src.tasks.aggregate_functions.slr import compute_slr, get_fetch_trait as get_slr_fetch_trait
from src.tasks.aggregate_functions.contract import compute_contract
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos

namespace AGGREGATE_FN {
    const AVG = 0;
    const SUM = 1;
    const MIN = 2;
    const MAX = 3;
    const COUNT = 4;
    const MERKLE = 5;
    const SLR = 6;
}

namespace Task {
    func init{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        keccak_ptr: KeccakBuiltin*,
        tasks: ComputationalTask*,
        pow2_array: felt*,
    }(n_tasks: felt, index: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        if (index == n_tasks) {
            return ();
        } else {
            local task_chain_id: felt;
            let (datalake_input: felt*) = alloc();
            local datalake_input_bytes_len: felt;
            local datalake_type: felt;

            let (tasks_input: felt*) = alloc();
            local tasks_input_bytes_len: felt;
            %{
                # TODO load it from program_input
                ids.task_chain_id = 1

                task = program_input["tasks"][ids.index]
                segments.write_arg(ids.datalake_input, hex_to_int_array(task["encoded_datalake"]))
                ids.datalake_input_bytes_len = task["datalake_bytes_len"]
                ids.datalake_type = task["datalake_type"]

                segments.write_arg(ids.tasks_input, hex_to_int_array(task["encoded_task"]))
                ids.tasks_input_bytes_len = task["task_bytes_len"]
            %}

            let (datalake_ptr) = Datalake.init(
                datalake_input, datalake_input_bytes_len, datalake_type
            );
            let (datalake_hash) = keccak(datalake_input, datalake_input_bytes_len);

            let (local task) = extract_params_and_construct_task{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
            }(
                chain_id=task_chain_id,
                input=tasks_input,
                input_bytes_len=tasks_input_bytes_len,
                datalake_hash=datalake_hash,
                datalake_ptr=datalake_ptr,
                datalake_type=datalake_type,
            );

            assert tasks[index] = task;

            return init(n_tasks=n_tasks, index=index + 1);
        }
    }

    // Executes the aggregate_fn of the passed tasks
    func execute{
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        ec_op_ptr,
        keccak_ptr: KeccakBuiltin*,
        poseidon_ptr: PoseidonBuiltin*,
        account_dict: DictAccess*,
        storage_dict: DictAccess*,
        header_dict: DictAccess*,
        block_tx_dict: DictAccess*,
        block_receipt_dict: DictAccess*,
        headers: Header*,
        pow2_array: felt*,
        tasks: ComputationalTask*,
        chain_info: ChainInfo,
    }(results: Uint256*, tasks_len: felt, index: felt) {
        alloc_locals;

        if (index == tasks_len) {
            return ();
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.AVG) {
            let fetch_trait = get_default_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let result = compute_avg(values=data_points, values_len=data_points_len);
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.SUM) {
            let fetch_trait = get_default_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let result = compute_sum(values_le=data_points, values_len=data_points_len);
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.MIN) {
            let fetch_trait = get_default_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let result = uint256_min_le(data_points, data_points_len);
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.MAX) {
            let fetch_trait = get_default_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let result = uint256_max_le(data_points, data_points_len);
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.COUNT) {
            let fetch_trait = get_default_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let (res_felt) = count_if(
                data_points, data_points_len, tasks[index].ctx_operator, tasks[index].ctx_value
            );
            let result = felt_to_uint256(res_felt);
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        if (tasks[index].aggregate_fn_id == AGGREGATE_FN.SLR) {
            let fetch_trait = get_slr_fetch_trait();
            with fetch_trait {
                let (data_points, data_points_len) = Datalake.fetch_data_points(tasks[index]);
            }
            let result = compute_slr(
                values=data_points, values_len=data_points_len, predict=tasks[index].ctx_value
            );
            assert [results] = result;

            %{
                target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
                print(f"Task Result({ids.index}): 0x{target_result}")
            %}

            return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
        }

        %{
            from contract_bootloader.objects import Module
            module = Module.Schema().load(program_input["module"])
            compiled_class = module.module_class
        %}

        let result = compute_contract();
        assert [results] = result;

        %{
            target_result = hex(ids.result.low + ids.result.high*2**128)[2:]
            print(f"Task Result({ids.index}): 0x{target_result}")
        %}

        return execute(results=results + Uint256.SIZE, tasks_len=tasks_len, index=index + 1);
    }
}

// Internal Functions:
func extract_params_and_construct_task{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(
    chain_id: felt,
    input: felt*,
    input_bytes_len: felt,
    datalake_hash: Uint256,
    datalake_ptr: felt*,
    datalake_type: felt,
) -> (task: ComputationalTask) {
    alloc_locals;
    // HeaderProp Input Layout:
    // 0-3: data_lake_hash
    // 4-7: aggregate_fn_id (chunk 7: value, chunks 4-6: padding)
    // 8-11: ctx_operator (chunk 11: value, chunks 7-10: padding)
    // 12-15: ctx_value

    // Copy data_lake_hash
    let datalake_hash_low = [input] + [input + 1] * 0x10000000000000000;
    let datalake_hash_high = [input + 2] + [input + 3] * 0x10000000000000000;

    // ensure task contains correct data lake hash
    assert datalake_hash_low = datalake_hash.low;
    assert datalake_hash_high = datalake_hash.high;

    let (hash) = keccak(input, input_bytes_len);

    let task_word = [input + 7];
    let task = extract_byte_at_pos(task_word, 7, pow2_array);
    // ensure aggregate_fn_id is not overflowing
    assert [input + 6] = 0;

    if (task == AGGREGATE_FN.COUNT) {
        let operator_word = [input + 11];
        let ctx_operator = extract_byte_at_pos(operator_word, 7, pow2_array);

        let ctx_value_le = Uint256(
            low=[input + 12] + [input + 13] * 0x10000000000000000,
            high=[input + 14] + [input + 15] * 0x10000000000000000,
        );
        let (ctx_value) = uint256_reverse_endian(ctx_value_le);

        return (
            task=ComputationalTask(
                chain_id=chain_id,
                hash=hash,
                datalake_ptr=datalake_ptr,
                datalake_type=datalake_type,
                aggregate_fn_id=AGGREGATE_FN.COUNT,
                ctx_operator=ctx_operator,
                ctx_value=ctx_value,
            ),
        );
    }
    if (task == AGGREGATE_FN.SLR) {
        let ctx_value_le = Uint256(
            low=[input + 12] + [input + 13] * 0x10000000000000000,
            high=[input + 14] + [input + 15] * 0x10000000000000000,
        );
        let (ctx_value) = uint256_reverse_endian(ctx_value_le);

        return (
            task=ComputationalTask(
                chain_id=chain_id,
                hash=hash,
                datalake_ptr=datalake_ptr,
                datalake_type=datalake_type,
                aggregate_fn_id=AGGREGATE_FN.SLR,
                ctx_operator=0,
                ctx_value=ctx_value,
            ),
        );
    }
    return (
        task=ComputationalTask(
            chain_id=chain_id,
            hash=hash,
            datalake_ptr=datalake_ptr,
            datalake_type=datalake_type,
            aggregate_fn_id=task,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        ),
    );
}
