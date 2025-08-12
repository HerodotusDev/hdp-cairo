from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.keccak_state import KeccakBuiltinState
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak_felts_bigend
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.memset import memset
from starkware.cairo.common.registers import get_label_location

// Specifies the hash memory structure. Same as struct HashBuiltin for compatibility
struct TruncatedKeccak {
    x: felt,
    y: felt,
    result: felt,
}

// A 160 msb truncated version of keccak:
//   keccak(x, y) >> 96.
// Note: This version hashes the big-endian representations of x and y.
func keccak160{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    x: felt, y: felt
) -> (res: felt) {
    alloc_locals;

    // Allocate memory for the two input felts
    let (elements: felt*) = alloc();
    assert elements[0] = x;
    assert elements[1] = y;

    // Compute the keccak hash of the big-endian representations of the felts.
    // keccak_felts_bigend handles input preparation and hashing,
    // returning the hash in big-endian format.
    // Input size is 2 * 32 bytes = 64 bytes.
    let (hash_be: Uint256) = keccak_felts_bigend(n_elements=2, elements=elements);

    // Get the top 32 bits from the low part (H_127..H_96)
    // Since hash_be.low is big-endian, these are the most significant bits.
    let (low_top32, _) = unsigned_div_rem(hash_be.low, 2 ** 96);

    // Combine hash_be.high (top 128 bits) and low_top32 (next 32 bits)
    // result = (hash_be.high << 32) | low_top32
    let result = hash_be.high * (2 ** 32) + low_top32;

    return (res=result);
}

func finalize_truncated_keccak{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    ptr_start: TruncatedKeccak*, ptr_end: TruncatedKeccak*
) {
    alloc_locals;
    
    // Check if we've processed all elements
    if (ptr_start == ptr_end) {
        return ();
    }

    // Compute the truncated keccak hash of x and y
    let (expected_result) = keccak160(ptr_start.x, ptr_start.y);
    
    // Verify that the computed hash matches the stored result
    assert expected_result = ptr_start.result;
    
    // Process the next element
    finalize_truncated_keccak(ptr_start + TruncatedKeccak.SIZE, ptr_end);
    return ();
}