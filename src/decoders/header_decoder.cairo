from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_read

from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from src.rlp import rlp_list_retrieve, le_chunks_to_uint256
from packages.eth_essentials.lib.utils import felt_divmod

from packages.eth_essentials.lib.mmr import hash_subtree_path
from src.types import MMRMeta
from packages.eth_essentials.lib.block_header import (
    extract_block_number_big,
    reverse_block_header_chunks,
)

namespace HeaderField {
    const PARENT = 0;
    const UNCLE = 1;
    const COINBASE = 2;
    const STATE_ROOT = 3;
    const TRANSACTION_ROOT = 4;
    const RECEIPT_ROOT = 5;
    const BLOOM = 6;
    const DIFFICULTY = 7;
    const NUMBER = 8;
    const GAS_LIMIT = 9;
    const GAS_USED = 10;
    const TIMESTAMP = 11;
    const EXTRA_DATA = 12;
    const MIX_HASH = 13;
    const NONCE = 14;
    const BASE_FEE_PER_GAS = 15;
    const WITHDRAWALS_ROOT = 16;
    const BLOB_GAS_USED = 17;
    const EXCESS_BLOB_GAS = 18;
    const PARENT_BEACON_BLOCK_ROOT = 19;
}

namespace HeaderDecoder {
    func get_block_number{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*
    ) -> felt {
        let value_le = get_dynamic_field(rlp, 8);
        let (value) = uint256_reverse_endian(value_le);
        assert value.high = 0x0;  // u128 is sufficient for the time being
        return value.low;
    }

    func get_field_felt{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt
    ) -> (value: felt*, value_len: felt, bytes_len: felt) {
        if (field == HeaderField.COINBASE) {
            let value = get_address_value(rlp, 8, 6);
            return (value=value, value_len=3, bytes_len=20);
        }

        if (field == HeaderField.BLOOM) {
            return get_bloom_filter(rlp);
        }

        if (field == HeaderField.EXTRA_DATA) {
            return get_dynamic_field_bytes(rlp, 12);
        }

        assert 1 = 0;
        return (value=rlp, value_len=0, bytes_len=0);
    }

    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt
    ) -> Uint256 {
        if (field == HeaderField.PARENT) {
            return get_hash_value(rlp, 0, 4);
        }
        if (field == HeaderField.UNCLE) {
            return get_hash_value(rlp, 4, 5);
        }
        if (field == HeaderField.COINBASE) {
            assert 1 = 0;  // must use get_coinbase
        }
        if (field == HeaderField.STATE_ROOT) {
            return get_hash_value(rlp, 11, 3);
        }
        if (field == HeaderField.TRANSACTION_ROOT) {
            return get_hash_value(rlp, 15, 4);
        }
        if (field == HeaderField.RECEIPT_ROOT) {
            return get_hash_value(rlp, 19, 5);
        }
        if (field == HeaderField.BLOOM) {
            // not implemented
            assert 1 = 0;
        }
        if (field == HeaderField.EXTRA_DATA) {
            assert 1 = 0;
        }

        // field is part of the dynamic section
        return get_dynamic_field(rlp, field);
    }

    func get_dynamic_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt
    ) -> Uint256 {
        let (value, value_len, bytes_len) = get_dynamic_field_bytes(rlp, field);
        return le_chunks_to_uint256(value, value_len, bytes_len);
    }

    func get_dynamic_field_bytes{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt
    ) -> (value: felt*, value_len: felt, bytes_len: felt) {
        let start_byte = 448;  // 20 + 5*32 + 256 + encoding bytes
        let field_idx = field - 7;  // we have 7 static fields that we skip

        let (res, res_len, bytes_len) = rlp_list_retrieve(
            rlp=rlp, field=field_idx, item_starts_at_byte=start_byte, counter=0
        );

        return (value=res, value_len=res_len, bytes_len=bytes_len);
    }
}

func get_hash_value{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    rlp: felt*, word_idx: felt, offset: felt
) -> Uint256 {
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

    let res_low = rlp_2_right * pow2_array[shifter + 64] + rlp_1 * pow2_array[shifter] + rlp_0;
    let res_high = rlp_4 * pow2_array[shifter + 64] + rlp_3 * pow2_array[shifter] + rlp_2_left;

    return (Uint256(low=res_low, high=res_high));
}

func get_address_value{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    rlp: felt*, word_idx: felt, offset: felt
) -> felt* {
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
    let last_divisor = pow2_array[(offset - 4) * 8];  // address is 20 bytes, so we need to subtract 4 from the offset
    let (trash, rlp_3_right) = felt_divmod(rlp_3, last_divisor);
    assert [addr + 2] = rlp_3_right * pow2_array[shifter] + rlp_2_left;

    return (addr);
}

func get_bloom_filter{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    rlp: felt*
) -> (value: felt*, value_len: felt, bytes_len: felt) {
    // the bloom filter always seems to start at byte 192, so we can increment the pointer and return
    return (value=rlp + 24, value_len=32, bytes_len=256);
}
