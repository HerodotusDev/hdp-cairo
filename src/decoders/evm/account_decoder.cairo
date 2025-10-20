from src.utils.rlp import rlp_list_retrieve, le_chunks_to_be_uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

struct AccountKey {
    chain_id: felt,
    block_number: felt,
    address: felt,
}

namespace AccountField {
    const NONCE = 0;
    const BALANCE = 1;
    const STATE_ROOT = 2;
    const CODE_HASH = 3;
}

namespace AccountDecoder {
    func get_field{
        keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
    }(rlp: felt*, field: felt, key: AccountKey*) -> (res_array: felt*, res_len: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (res, res_len, bytes_len) = rlp_list_retrieve(
            rlp=rlp, field=field, item_starts_at_byte=2, counter=0
        );

        let (local result) = le_chunks_to_be_uint256(
            elements=res, elements_len=res_len, bytes_len=bytes_len
        );

        return (res_array=&result, res_len=2);
    }
}
