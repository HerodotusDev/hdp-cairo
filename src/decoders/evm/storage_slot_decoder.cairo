from src.utils.rlp import decode_rlp_word_to_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

struct StorageKey {
    chain_id: felt,
    block_number: felt,
    address: felt,
    storage_slot: Uint256,
}

namespace StorageSlotDecoder {
    func get_word{keccak_ptr: KeccakBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt, key: StorageKey*
    ) -> (res_array: felt*, res_len: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let le_value = decode_rlp_word_to_uint256(rlp=rlp);
        let (local result) = uint256_reverse_endian(le_value);
        return (res_array=&result, res_len=2);
    }
}
