from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.uint256 import Uint256
from src.types import Account, AccountProof, Header, AccountValues
from src.rlp import retrieve_from_rlp_list_via_idx, le_u64_array_to_uint256
from src.memorizer import HeaderMemorizer, AccountMemorizer

namespace ACCOUNT_FIELD {
    const NONCE = 0;
    const BALANCE = 1;
    const STATE_ROOT = 2;
    const CODE_HASH = 3;
}

namespace AccountDecoder {
    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt
    ) -> Uint256 {
        alloc_locals;

        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(
            rlp=rlp, field=field, item_starts_at_byte=2, counter=0
        );

        let result = le_u64_array_to_uint256(
            elements=res, elements_len=res_len, bytes_len=bytes_len
        );

        return (result);
    }
}
