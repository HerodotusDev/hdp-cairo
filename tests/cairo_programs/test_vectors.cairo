from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.builtin_keccak.keccak import keccak
from src.types import BlockSampledDataLake, ComputationalTask
from src.tasks.computational import AGGREGATE_FN
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from src.datalakes.datalake import DatalakeType
namespace BlockSampledDataLakeMocker {
    func get_header_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
        alloc_locals;

        let (datalake_input: felt*) = alloc();
        local datalake: BlockSampledDataLake;
        local datalake_bytes_len: felt;

        %{
            ids.datalake.chain_id = 11155111
            ids.datalake.block_range_start = 5382810
            ids.datalake.block_range_end = 5382815
            ids.datalake.increment = 1
            ids.datalake.property_type = 1
            ids.datalake.properties = segments.gen_arg([8])

            datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0xA736AA0000000000,0x0,0x0,0x0,0x9a22520000000000,0x0,0x0,0x0,0x9f22520000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x200000000000000,0x801,0x0,0x0,0x0]
            ids.datalake_bytes_len = 256
            segments.write_arg(ids.datalake_input, datalake_input)
        %}

        return (datalake_input, datalake_bytes_len, datalake, 1);
    }

    func get_account_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
        alloc_locals;

        let (datalake_input) = alloc();
        local datalake: BlockSampledDataLake;
        local datalake_bytes_len: felt;

        %{
            ids.datalake.chain_id = 11155111
            ids.datalake.block_range_start = 4952100
            ids.datalake.block_range_end = 4952120
            ids.datalake.increment = 1
            ids.datalake.property_type = 2
            ids.datalake.properties = segments.gen_arg([0x1,0x7f2c6f930306d3aa736b3a6c6a98f512f74036d4])

            datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0xA736AA0000000000,0x0,0x0,0x0,0x24904b0000000000,0x0,0x0,0x0,0x38904b0000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x1600000000000000,0xd30603936f2c7f02,0xf5986a6c3a6b73aa,0x1d43640f712,0x0]        
            ids.datalake_bytes_len = 256
            segments.write_arg(ids.datalake_input, datalake_input)
        %}

        return (datalake_input, datalake_bytes_len, datalake, 2);
    }

    func get_storage_property() -> (
        datalake_input: felt*,
        datalake_input_bytes_len: felt,
        datalake: BlockSampledDataLake,
        property_type: felt,
    ) {
        alloc_locals;

        let (datalake_input) = alloc();
        local datalake: BlockSampledDataLake;
        local datalake_bytes_len: felt;

        %{
            ids.datalake.chain_id = 11155111
            ids.datalake.block_range_start = 5382810
            ids.datalake.block_range_end = 5382815
            ids.datalake.increment = 1
            ids.datalake.property_type = 3
            ids.datalake.properties = segments.gen_arg([0x75CeC1db9dCeb703200EAa6595f66885C962B920,0x0,0x2])

            datalake_input = [0x0,0x0,0x0,0x0,0x0,0x0,0x0,0xA736AA0000000000,0x0,0x0,0x0,0x9a22520000000000,0x0,0x0,0x0,0x9f22520000000000,0x0,0x0,0x0,0x100000000000000,0x0,0x0,0x0,0xa000000000000000,0x0,0x0,0x0,0x3500000000000000,0xb7ce9ddbc1ce7503,0x68f69565aa0e2003,0x20b962c985,0x0,0x0,0x0,0x200000000,0x0]
            ids.datalake_bytes_len = 288
            segments.write_arg(ids.datalake_input, datalake_input)
        %}

        return (datalake_input, datalake_bytes_len, datalake, 3);
    }
}

namespace BlockSampledTaskMocker {
    func get_init_data() -> (
        task: ComputationalTask,
        tasks_inputs: felt**,
        tasks_bytes_len: felt*,
        datalake: BlockSampledDataLake,
        datalakes_inputs: felt**,
        datalakes_bytes_len: felt*,
        tasks_len: felt,
    ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, prop_id
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        let (tasks_bytes_len) = alloc();

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            # mocks python params that are available during full flow
            block_sampled_tasks = [{'property_type': 1 }]
            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            segments.write_arg(ids.tasks_bytes_len, [len(task_bytes)])
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0x407E98D423A7BB2DBF09B0E42601FC9B, high=0xEF8B01F35B404615F0339EEFAE7719A2
            ),
            datalake_ptr=cast(&datalake, felt*),
            datalake_type=0,
            aggregate_fn_id=AGGREGATE_FN.AVG,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (tasks_inputs: felt**) = alloc();
        let (datalakes_inputs: felt**) = alloc();
        let (datalakes_bytes_len: felt*) = alloc();
        assert tasks_inputs[0] = task_input;
        assert datalakes_inputs[0] = datalake_input;
        assert datalakes_bytes_len[0] = datalake_bytes_len;

        return (
            task, tasks_inputs, tasks_bytes_len, datalake, datalakes_inputs, datalakes_bytes_len, 1
        );
    }

    func get_avg_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little

            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0x29EDECDB24D47C8CFA6FA2C538D8C0AD, high=0x319EF071671DCEA889F113920CBB48DD
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.AVG,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_sum_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0xBB8F8BE052FA69FC932F586EFF3FFF82, high=0x800F013218B39FE67DF7C0D1F7246CB8
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.SUM,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_min_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0xCC50E918B8F9F1DF33CC8C9C86CBF4F0, high=0x133680AC8C33499C4364FEFFCB804E94
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.MIN,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_max_task{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
        ) -> (
            task: ComputationalTask,
            tasks_inputs: felt*,
            tasks_bytes_len: felt,
            datalake: BlockSampledDataLake,
            datalake_hash: Uint256,
        ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A000000000000000000000000000000000000000000000000000000000000000300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}

        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0x3ADE97877E3502F427D1853837DD1B41, high=0x67905CD8E3ACC23EFF54245537FFA500
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.MAX,
            ctx_operator=0,
            ctx_value=Uint256(low=0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }

    func get_count_if_task{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
    }() -> (
        task: ComputationalTask,
        tasks_inputs: felt*,
        tasks_bytes_len: felt,
        datalake: BlockSampledDataLake,
        datalake_hash: Uint256,
    ) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (
            datalake_input, datalake_bytes_len, local datalake, _
        ) = BlockSampledDataLakeMocker.get_header_property();
        let (task_input) = alloc();
        local tasks_bytes_len: felt;

        %{
            from tools.py.utils import bytes_to_8_bytes_chunks_little
            task_bytes = bytes.fromhex("6A3B90F31FC36A592E67293D5D9359BADCD9B6E2B5E078B349B546A5AEE0904A0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000186a0")
            ids.tasks_bytes_len = len(task_bytes)
            segments.write_arg(ids.task_input, bytes_to_8_bytes_chunks_little(task_bytes))
        %}
        let datalake_ptr: felt* = cast(&datalake, felt*);

        let task = ComputationalTask(
            chain_id=0x1,
            hash=Uint256(
                low=0x18E95103512DFA47ABF4237FB5FBF673, high=0xE6FF175F1DAB2E8AC4315F634B27BE8E
            ),
            datalake_ptr=datalake_ptr,
            datalake_type=DatalakeType.BLOCK_SAMPLED,
            aggregate_fn_id=AGGREGATE_FN.COUNT,
            ctx_operator=1,
            ctx_value=Uint256(low=0x186a0, high=0),
        );

        let (datalake_hash) = keccak(datalake_input, datalake_bytes_len);

        return (task, task_input, tasks_bytes_len, datalake, datalake_hash);
    }
}
