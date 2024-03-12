from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.libs.utils import felt_divmod
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)
from starkware.cairo.common.alloc import alloc

// retieves an RLP value based on the elements index in the RLP array
// The validity of RLP is not checked in this function.
// Params:
// - rlp: the rlp encoded state array
// - value_idx: the index of the value to retrieve (nonce, balance, stateRoot, codeHash) as index
// - item_starts_at_byte: the byte at which the item starts. Since the two hashes are 32 bytes long, we know the list is going to be long, so we can skip the first 2 bytes
// - counter: the current counter of the recursive function
// Returns: LE 8bytes array of the value + the length of the array
func retrieve_rlp_element_via_idx{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
} ( rlp: felt*, value_idx: felt, item_starts_at_byte: felt, counter: felt) -> (res: felt*, res_len: felt, bytes_len: felt) {
    alloc_locals;

    let (item_starts_at_word, item_start_offset) = felt_divmod(
        item_starts_at_byte, 8
    );

    let current_item = extract_byte_at_pos(
        rlp[item_starts_at_word],
        item_start_offset,
        pow2_array
    );

    local item_has_prefix: felt;
    %{
        if ids.current_item < 0x80:
            ids.item_has_prefix = 0
        else:
            ids.item_has_prefix = 1
    %}

    local current_item_len: felt;

    if (item_has_prefix == 1) {
        assert [range_check_ptr] = current_item - 0x80; // validates item_has_prefix hint
        current_item_len = current_item - 0x80;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len + 1;
    } else {
        assert [range_check_ptr] = 0x7f - current_item; // validates item_has_prefix hint
        current_item_len = 1;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len;
    }

    let range_check_ptr = range_check_ptr + 1;
    
    if (value_idx == counter) {
        // handle empty bytes case
        if(current_item_len == 0) {
            let (res: felt*) = alloc();
            assert res[0] = 0;
            return (res=res, res_len=1, bytes_len=1);
        } 

        // handle prefix case
        if (item_has_prefix == 1) {
            let (word_idx, offset) = felt_divmod(
                item_starts_at_byte + 1, 8
            );
            
            let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
                array=rlp,
                start_word=word_idx,
                start_offset=offset,
                n_bytes=current_item_len,
                pow2_array=pow2_array
            );

            return (res=res, res_len=res_len, bytes_len=current_item_len);
        } else {
            // handle single byte case
            let (res: felt*) = alloc();
            assert res[0] = current_item;
            return (res=res, res_len=1, bytes_len=1);
        }
    }

    return retrieve_rlp_element_via_idx(
        rlp=rlp,
        value_idx=value_idx,
        item_starts_at_byte=next_item_starts_at_byte,
        counter=counter+1,
    );
}