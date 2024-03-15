from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import Account, AccountProof, Header, AccountValues
from src.libs.block_header import extract_state_root_little
from src.hdp.rlp import retrieve_rlp_element_via_idx
from src.hdp.utils import keccak_hash_array_to_uint256, le_u64_array_to_uint256
from src.hdp.memorizer import HeaderMemorizer, AccountMemorizer
from src.hdp.header import HeaderReader


namespace AccountReader {
    // retrieves the account state root from rlp encoded account state
    func get_state_root{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    } (rlp: felt*) -> Uint256 {
        alloc_locals;

        let (res, res_len, _byte_len) = retrieve_rlp_element_via_idx(rlp=rlp, value_idx=2, item_starts_at_byte=2, counter=0);

        let result = keccak_hash_array_to_uint256(
            elements=res,
            elements_len=res_len
        );

        return result;
    }

    func get_by_index{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    } (rlp: felt*, value_idx: felt) -> Uint256 {
        alloc_locals;

        let (res, res_len, bytes_len) = retrieve_rlp_element_via_idx(rlp=rlp, value_idx=value_idx, item_starts_at_byte=2, counter=0);

        local is_hash: felt;
        %{
            # We need to ensure we decode the felt* in the correct format
            if ids.value_idx <= 1:
                # Int Value: nonce=0, balance=1
                ids.is_hash = 0
            else:
                # Hash Value: stateRoot=2, codeHash=3
                ids.is_hash = 1
        %}

        if (is_hash == 0) {
            assert [range_check_ptr] = 1 - value_idx; // validates is_hash hint
            tempvar range_check_ptr = range_check_ptr + 1;
            let result = le_u64_array_to_uint256(
                elements=res,
                elements_len=res_len,
                bytes_len=bytes_len,
                to_be=1
            );

            return result;
        } else {
            assert [range_check_ptr] = value_idx - 2; // validates is_hash hint
            tempvar range_check_ptr = range_check_ptr + 1;
            let result = keccak_hash_array_to_uint256(
                elements=res,
                elements_len=res_len
            );

            return result;
        }
    }
}