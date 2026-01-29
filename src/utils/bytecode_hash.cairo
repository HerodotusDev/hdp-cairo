// Bytecode hashing and verification for constrained bytecode (EVM code hash).
// Bytecode is passed as BytecodeLeWords format: 64-bit LE words + last word + last num bytes.
// Verification computes keccak(bytecode), reverses endianness to EVM (big-endian), and compares.
//
// Use builtin_keccak (KeccakBuiltin*) so the runner manages the buffer; avoids cairo_keccak's
// memcpy to an alloc'd segment which can hit zero-initialized memory under some runners.

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.builtin_keccak.keccak import keccak

from src.utils.utils import copy_prefix_words, get_byte_at_offset

// Error felt for code hash mismatch (must match EVM expectations).
const BYTECODE_CODE_HASH_MISMATCH = 'Bytecode: code hash mismatch';

// Verifies that the keccak hash of the given bytecode (BytecodeLeWords format) equals the expected code hash.
// Reverses endianness of the computed hash to match EVM (big-endian) before comparison.
// Panics (assert failure) on mismatch.
//
// - bytecode_words: pointer to the array of 64-bit little-endian words (length = words_len).
// - words_len: number of full 64-bit words.
// - lastInputWord: the last (possibly partial) 64-bit word.
// - lastInputNumBytes: number of bytes in lastInputWord (0 if no partial word, else 1..7).
// - expected_hash: EVM code hash as Uint256 (big-endian).
func verify_bytecode_hash{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(bytecode_words: felt*, words_len: felt, lastInputWord: felt, lastInputNumBytes: felt, expected_hash: Uint256) -> () {
    alloc_locals;

    tempvar n_bytes = words_len * 8 + lastInputNumBytes;
    // Allocate buffer: full words + one extra word if we have a partial last word.
    let (word_buf: felt*) = alloc();
    copy_prefix_words(src=bytecode_words, dst=word_buf, n_words=words_len);
    if (lastInputNumBytes != 0) {
        assert word_buf[words_len] = lastInputWord;
    }

    // builtin_keccak returns little-endian Uint256 (same as cairo_keccak).
    let (calculated_le: Uint256) = keccak(inputs=word_buf, n_bytes=n_bytes);
    let (calculated_be: Uint256) = uint256_reverse_endian(calculated_le);

    assert calculated_be.low = expected_hash.low;
    assert calculated_be.high = expected_hash.high;

    return ();
}

// Extracts the raw byte array (each byte as a felt 0..255) from BytecodeLeWords in memory.
// Used after verification to store bytecode in the EVM memorizer (u8 array format).
//
// - bytecode_le_words_ptr: pointer to BytecodeLeWords layout: [words_len, word0, ..., lastInputWord, lastInputNumBytes].
// - Returns: (u8_array: felt*, len: felt) where u8_array points to an array of felts (one per byte) and len is the byte count.
func bytecode_le_words_to_u8_array{
    range_check_ptr,
    pow2_array: felt*,
}(bytecode_le_words_ptr: felt*) -> (u8_array: felt*, len: felt) {
    alloc_locals;

    let words_len = [bytecode_le_words_ptr];
    let words_start = bytecode_le_words_ptr + 1;
    let lastInputWord = [bytecode_le_words_ptr + 1 + words_len];
    let lastInputNumBytes = [bytecode_le_words_ptr + 2 + words_len];

    let total_bytes = words_len * 8 + lastInputNumBytes;

    // Build contiguous word buffer for byte extraction (same as verify path).
    let (word_buf: felt*) = alloc();
    copy_prefix_words(src=words_start, dst=word_buf, n_words=words_len);
    if (lastInputNumBytes != 0) {
        assert word_buf[words_len] = lastInputWord;
    }

    // Allocate output array (one felt per byte).
    let (out: felt*) = alloc();
    bytecode_le_words_to_u8_array_loop(base=word_buf, out=out, total_bytes=total_bytes, i=0);

    return (u8_array=out, len=total_bytes);
}

// Inner loop: write each byte (as felt) to out[i].
func bytecode_le_words_to_u8_array_loop{
    range_check_ptr,
    pow2_array: felt*,
}(base: felt*, out: felt*, total_bytes: felt, i: felt) -> () {
    if (i == total_bytes) {
        return ();
    }
    let (b) = get_byte_at_offset(base, pow2_array, i);
    assert out[i] = b;
    bytecode_le_words_to_u8_array_loop(base=base, out=out, total_bytes=total_bytes, i=i + 1);
    return ();
}
