// Minimal Cairo0 test program for verify_bytecode_hash.
// Run with: cairo-run --program=bytecode_verify_test_compiled.json --program_input=<input.json> --layout=starknet_with_keccak
// program_input format: { "words_len", "words", "last_input_word", "last_input_num_bytes", "expected_hash_low", "expected_hash_high" }
//
// Uses builtin_keccak (KeccakBuiltin*): runner manages the buffer, no finalize_keccak.
// Same pattern as offchain-evm-headers-processor chunk_processor.cairo.

%builtins output pedersen range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, HashBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256

from src.utils.bytecode_hash import verify_bytecode_hash

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;

    local bytecode_words: felt*;
    local words_len: felt;
    local lastInputWord: felt;
    local lastInputNumBytes: felt;
    local expected_hash: Uint256;
    %{
    # program_input: words_len, words (list), last_input_word, last_input_num_bytes, expected_hash_low, expected_hash_high (all as decimal strings or ints)
    data = program_input
    def to_felt(x):
        return int(x) if isinstance(x, str) else x
    segment = segments.add()
    memory[segment] = to_felt(data['words_len'])
    for i, w in enumerate(data['words']):
        memory[segment + 1 + i] = to_felt(w)
    n = len(data['words'])
    memory[segment + 1 + n] = to_felt(data['last_input_word'])
    memory[segment + 2 + n] = to_felt(data['last_input_num_bytes'])
    ids.bytecode_words = segment + 1
    ids.words_len = to_felt(data['words_len'])
    ids.lastInputWord = to_felt(data['last_input_word'])
    ids.lastInputNumBytes = to_felt(data['last_input_num_bytes'])
    ids.expected_hash.low = to_felt(data['expected_hash_low'])
    ids.expected_hash.high = to_felt(data['expected_hash_high'])
    %}
    with keccak_ptr {
        verify_bytecode_hash(
            bytecode_words=bytecode_words,
            words_len=words_len,
            lastInputWord=lastInputWord,
            lastInputNumBytes=lastInputNumBytes,
            expected_hash=expected_hash,
        );
    }
    return ();
}
