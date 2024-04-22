from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.uint256 import Uint256

from src.libs.utils import word_reverse_endian_64
from src.hdp.types import TransactionsInBlockDatalake
from src.libs.rlp_little import extract_byte_at_pos


func init_txs_in_block{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*}(
    input: felt*, input_bytes_len: felt
) -> (res: TransactionsInBlockDatalake) {

    // HeaderProp Input Layout:
    // 0-3: DatalakeCode.BlockSampled
    // 4-7: target_block
    // 8-11: increment
    // 12-15: dynamic data offset
    // 16-19: dynamic data element count
    // 20-23: sampled_property (type, field)
    assert [input + 3] = 0x100000000000000;  // DatalakeCode.TxsInBlock == 1

    assert [input + 6] = 0;  // first 3 chunks of block_range_start should be 0
    let (target_block) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0;  // first 3 chunks of block_range_end should be 0
    let (increment) = word_reverse_endian_64([input + 11]);

    let type = extract_byte_at_pos([input + 20], 0, pow2_array);
    let property = extract_byte_at_pos([input + 20], 1, pow2_array); // first chunk cointains type + property

    assert [input + 21] = 0;  // remaining chunks should be 0

    return (res=TransactionsInBlockDatalake(
        target_block=target_block,
        increment=increment,
        type=type,
        sampled_property=property,
    ));
}