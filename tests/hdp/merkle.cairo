%builtins range_check bitwise keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from tests.hdp.test_vectors import BlockSampledTaskMocker
from src.hdp.merkle import compute_tasks_root, compute_results_root, hash_pair
from src.hdp.utils import compute_results_entry

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
    
    computes_output_roots{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    }();
    hash_pair_sorting{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    }();

    return ();
}

func computes_output_roots{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
    alloc_locals;

    let (tasks,_,_,_,_,tasks_len) = BlockSampledTaskMocker.get_account_task();

    let tasks_root = compute_tasks_root{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    } (tasks, tasks_len);

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

func hash_pair_sorting{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
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