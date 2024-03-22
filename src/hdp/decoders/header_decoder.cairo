from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read

from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256
from src.hdp.rlp import retrieve_from_rlp_list_via_idx, le_u64_array_to_uint256
from src.libs.utils import felt_divmod

from src.libs.mmr import hash_subtree_path
from src.hdp.types import (
    Header,
    HeaderProof,
    MMRMeta,
)
from src.libs.block_header import extract_block_number_big, reverse_block_header_chunks
from src.hdp.memorizer import HeaderMemorizer

namespace HeaderDecoder {
    func get_coinbase{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*) -> felt* {
        return get_address_value(rlp, 8, 6);
    }

    func get_state_root{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*) -> Uint256 {
        return get_field_by_index(rlp, 3);
    }

    func get_block_number{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*) -> felt {
        let value = get_dynamic_field(rlp, 8, 1);
        assert value.high = 0x0; // u128 is sufficient for the time being
        return value.low;
    }

    func get_felt_fields_by_index{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*, field: felt) -> (value: felt*, value_len: felt, bytes_len: felt) {

        if(field == 2) {
            let value = get_address_value(rlp, 8, 6);
            return (value=value, value_len=3, bytes_len=20);
        }

        if(field == 6) {
            return get_bloom_filter(rlp);
        }

        //extraData
        if(field == 12) {
            return get_dynamic_field_bytes(rlp, 12);
        }

        assert 1 = 0;
        return (value=rlp, value_len=0, bytes_len=0);
    }

    func get_field_by_index{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*, field: felt, ) -> Uint256 {
        alloc_locals;
        
        //parent LE
        if(field == 0) {
            return get_hash_value(rlp, 0, 4);
        }
        //uncle LE
        if(field == 1){
            return get_hash_value(rlp, 4, 5);
        }
        // coinbase
        if(field == 2) {
            assert 1 = 0; // must use get_coinbase
        }
        //state_root LE
        if(field == 3){
            return get_hash_value(rlp, 11, 3);
        }
        //tx_root LE
        if(field == 4){
            return get_hash_value(rlp, 15, 4);
        }
        //receipts_root LE
        if(field == 5){
            return get_hash_value(rlp, 19, 5);
        }
        // bloom filter
        if(field == 6) {
            // not implemented
            assert 1 = 0;
        }
        //mixData
        if(field == 12) {
            assert 1 = 0;
        }

         // ToDo: make sound!
        local to_be: felt;
        %{
            if ids.field <= 6: # hashes we keep in LE.
                ids.to_be = 0
            elif ids.field == 13 or ids.field == 16 or ids.field == 19: # these are also hashes
                ids.to_be = 0
            else:
                ids.to_be = 1
        %}

        // field is part of the dynamic section
        return get_dynamic_field(rlp, field, to_be);
    }

    func get_dynamic_field{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*, field: felt, to_be: felt) -> Uint256 {
        let (value, value_len, bytes_len) = get_dynamic_field_bytes(rlp, field);
        return le_u64_array_to_uint256(value, value_len, bytes_len, to_be);
    }

    func get_dynamic_field_bytes{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(rlp: felt*, field: felt) -> (value: felt*, value_len: felt, bytes_len: felt) {
        let start_byte = 448; // 20 + 5*32 + 256 + encoding bytes
        let field_idx = field - 7; // we have 7 static fields that we skip
        
        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(
            rlp=rlp,
            value_idx=field_idx,
            item_starts_at_byte=start_byte,
            counter=0,
        );

        return (value=res, value_len=res_len, bytes_len=bytes_len);
    }
}

func get_hash_value{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*, word_idx: felt, offset: felt) -> Uint256 {
    let shifter = (8 - offset) * 8;
    let devisor = pow2_array[offset * 8];

    let rlp_0 = rlp[word_idx];
    let (rlp_0, thrash) = felt_divmod(rlp_0, devisor);
    let rlp_1 = rlp[word_idx + 1];
    let rlp_2 = rlp[word_idx + 2];
    let (rlp_2_left, rlp_2_right) = felt_divmod(rlp_2, devisor);
    let rlp_3 = rlp[word_idx + 3];
    let rlp_4 = rlp[word_idx + 4];
    let (tash, rlp_4) = felt_divmod(rlp_4, devisor);

    let res_low = rlp_2_right * pow2_array[shifter+ 64] + rlp_1 * pow2_array[shifter] + rlp_0;
    let res_high = rlp_4 * pow2_array[shifter + 64] + rlp_3 * pow2_array[shifter] + rlp_2_left;

    return (Uint256(low=res_low, high=res_high));
}

func get_address_value{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*, word_idx: felt, offset: felt) -> felt* {
    let (addr) = alloc();

    let shifter = (8 - offset) * 8;
    let devisor = pow2_array[offset * 8];

    let rlp_0 = rlp[word_idx];
    let (rlp_0, thrash) = felt_divmod(rlp_0, devisor);
    let rlp_1 = rlp[word_idx + 1];
    let (rlp_1_left, rlp_1_right) = felt_divmod(rlp_1, devisor);
    assert [addr] = rlp_1_right * pow2_array[shifter] + rlp_0;

    let rlp_2 = rlp[word_idx + 2];
    let rlp_2_word = rlp_2;
    let (rlp_2_left, rlp_2_right) = felt_divmod(rlp_2, devisor);
    assert [addr + 1] = rlp_2_right * pow2_array[shifter] + rlp_1_left;

    let rlp_3 = rlp[word_idx + 3];
    let last_divisor = pow2_array[(offset - 4) * 8]; // address is 20 bytes, so we need to subtract 4 from the offset
    let (trash, rlp_3_right) = felt_divmod(rlp_3, last_divisor);
    assert [addr + 2] = rlp_3_right * pow2_array[shifter] + rlp_2_left;

    return (addr);
}

func get_bloom_filter{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*,) -> (value: felt*, value_len: felt, bytes_len: felt) {
    // the bloom filter always seems to start at byte 192, so we can increment the pointer and return
    return (value=rlp + 24, value_len=32, bytes_len=256);
}