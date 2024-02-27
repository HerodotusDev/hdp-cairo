from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.hdp.types import BlockSampledComputationalTask
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.uint256 import Uint256

func compute_root_mock{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(value: Uint256) -> Uint256 {
    alloc_locals;
    let (first_round_input) = alloc();
    let first_round_input_start = first_round_input;

    // convert to felts
    keccak_add_uint256{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        inputs=first_round_input
    }(
        num=value,
        bigend=0
    );

    // hash first round
    let (first_hash) = keccak(first_round_input_start, 32);

    let (second_round_input) = alloc();
    let second_round_input_start = second_round_input;
    keccak_add_uint256{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        inputs=second_round_input
    }(
        num=first_hash,
        bigend=0
    );

    let (result) = keccak_bigend(second_round_input_start, 32);

    %{
        print(f"result.low: {hex(ids.result.low)}")
        print(f"result.high: {hex(ids.result.high)}")
    %}

    return result;
}