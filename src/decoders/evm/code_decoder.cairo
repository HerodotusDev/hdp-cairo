from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math_cmp import is_le
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from packages.eth_essentials.lib.utils import felt_divmod
from src.utils.rlp import decode_long_value_len

struct CodeKey {
    chain_id: felt,
    label: felt,
    block_number: felt,
    address: felt,
}

namespace CodeDecoder {
    func decode{
        keccak_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
    }(rlp: felt*, field: felt, key: CodeKey*) -> (res_array: felt*, res_len: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        // Bytecode is encoded as an RLP String (short or long)
        // We need to extract the bytes and return pointers to unpacked array

        // 1. Parse header to find length and start offset
        let (value_len, start_offset) = decode_len_and_offset(rlp, pow2_array);

        // 2. Allocate output array
        let (bytecode: felt*) = alloc();

        // 3. Extract bytes loop
        extract_bytes_loop(rlp, start_offset, value_len, bytecode, 0);

        // 4. Return [bytecode_ptr, bytecode_len]
        let (res_array: felt*) = alloc();
        assert res_array[0] = cast(bytecode, felt);
        assert res_array[1] = value_len;

        return (res_array=res_array, res_len=2);
    }

    func decode_len_and_offset{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(rlp: felt*, pow2_array: felt*) -> (
        value_len: felt, start_offset: felt
    ) {
        alloc_locals;
        let rlp_int = cast(rlp, felt);
        if (rlp_int == 0) {
            return (0, 0);
        }

        let (word_idx, byte_offset) = felt_divmod(0, 8); // Start at 0
        let first_byte = extract_byte_at_pos(rlp[word_idx], byte_offset, pow2_array);
        
        // Pure Cairo implementation of RLP prefix check
        // Long string range: [0xb8, 0xbf]
        let ge_b8 = is_le(0xb8, first_byte);
        let le_bf = is_le(first_byte, 0xbf);
        local is_long = ge_b8 * le_bf;
        
        // Sanity check: if it's not long, it should be single byte or short string (< 0xb8)
        if (is_long == 0) {
             let valid_short = is_le(first_byte, 0xb7);
             with_attr error_message("Invalid RLP Bytecode Prefix") {
                 assert valid_short = 1;
             }
        }

        if (is_long == 0) {
            // Short string or single byte
            let is_single = is_le(first_byte, 0x7f);
            if (is_single == 1) {
                // Single byte: [0x00, 0x7f]
                return (value_len=1, start_offset=0);
            } else {
                // Short string [0x80, 0xb7]
                return (value_len=first_byte - 0x80, start_offset=1);
            }
        } else {
            // Long string [0xb8, 0xbf]
            let len_len = first_byte - 0xb7;
            let v_len = decode_long_value_len(rlp, 1, len_len, pow2_array);
            return (value_len=v_len, start_offset=1 + len_len);
        }
    }


    
    func extract_bytes_loop{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, start_offset: felt, len: felt, output: felt*, idx: felt
    ) {
        if (idx == len) {
            return ();
        }
        
        let (word, byte_off) = felt_divmod(start_offset + idx, 8);
        let byte = extract_byte_at_pos(rlp[word], byte_off, pow2_array);
        assert output[idx] = byte;
        
        return extract_bytes_loop(rlp, start_offset, len, output, idx + 1);
    }

}
