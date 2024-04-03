%builtins range_check bitwise keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from tests.hdp.test_vectors import BlockSampledTaskMocker
from src.hdp.merkle import compute_tasks_root, compute_results_root, hash_pair, compute_merkle_root
from src.hdp.utils import compute_results_entry

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    computes_output_roots{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }();
    hash_pair_sorting{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }();

    compute_merkle_root_test{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }();

    return ();
}

func computes_output_roots{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (tasks, _, _, _, _, tasks_len) = BlockSampledTaskMocker.get_account_task();

    let tasks_root = compute_tasks_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(tasks, tasks_len);

    assert tasks_root.low = 25249885786962326550128618884562747073;
    assert tasks_root.high = 303705675233408676159998938613428017230;

    let result = Uint256(low=100, high=0);
    let results_entry = compute_results_entry(tasks_root, result);

    assert results_entry.low = 52590437381030883083081982142525279579;
    assert results_entry.high = 305080544191682781037295485062205375969;

    let (results: Uint256*) = alloc();
    assert [results] = result;

    let results_root = compute_results_root(tasks, results, 1);

    assert results_root.low = 328630078149447953936045244953643482176;
    assert results_root.high = 260038522591081060757806935135508368687;

    return ();
}

func hash_pair_sorting{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    ) {
    alloc_locals;

    let a = Uint256(low=100, high=0);
    let b = Uint256(low=101, high=0);

    let c = Uint256(low=0, high=100);
    let d = Uint256(low=0, high=101);

    let hash_ab = hash_pair(a, b);

    // H(0x6400000000000000000000000000000000, 0x6500000000000000000000000000000000)
    assert hash_ab.low = 163291149559542241309179326071480931191;
    assert hash_ab.high = 295863837414419920236646088726537045337;

    // H(0x64, 0x65)
    let hash_cd = hash_pair(c, d);
    assert hash_cd.low = 13032766405138684239100038106974674315;
    assert hash_cd.high = 98233670034630048064327498362998938186;

    return ();
}

func compute_merkle_root_test{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (leafs: Uint256*) = alloc();

    %{
        from tools.py.utils import (
            split_128,
            reverse_endian_256,
        )

        # converts values to little endian and writes them to memory.
        def write_vals(ptr, values):
            for (i, value) in enumerate(values):
                reversed_value = reverse_endian_256(value)
                (low, high) = split_128(reversed_value)
                memory[ptr._reference_value + i * 2] = low
                memory[ptr._reference_value + i * 2 + 1] = high

        test_values =[
            0x0000000000000000000000000000000000000000000000000000000000000001,
            0x0000000000000000000000000000000000000000000000000000000000000002,
            0x000000000000000000000000000000000000000000000000000000000000007a,
            0x0000000000000000000000000000000000000000000000000000000000000004,
            0x0000000000000000000000000000000000000000000000000000000000000001
        ]

        write_vals(ids.leafs, test_values)
    %}

    // Values can be generated using the official OpenZepplin implementation in tools/js/merkle.js
    let root_one = compute_merkle_root(leafs, 1);
    assert root_one.high = 0xb5d9d894133a730aa651ef62d26b0ffa;
    assert root_one.low = 0x846233c74177a591a4a896adfda97d22;

    let root_two = compute_merkle_root(leafs, 2);
    assert root_two.high = 0xe685571b7e25a4a0391fb8daa09dc8d3;
    assert root_two.low = 0xfbb3382504525f89a2334fbbf8f8e92c;

    let root_three = compute_merkle_root(leafs, 3);
    assert root_three.high = 0x22a9fa23ace0a643334709a15031f455;
    assert root_three.low = 0x653508baac1e2f3aeb34494420d3926d;

    let root_four = compute_merkle_root(leafs, 4);
    assert root_four.high = 0x04a658c32b0f14901050b3649930b07c;
    assert root_four.low = 0xcb19e12ee6121c59fae29dbd2639d643;

    let root_five = compute_merkle_root(leafs, 5);
    assert root_five.high = 0x76a558f4880fd37907a3c306516dcb3e;
    assert root_five.low = 0x680616d84e8950d8050923bdd6ee51a7;

    return ();
}
