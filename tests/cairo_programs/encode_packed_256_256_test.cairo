%builtins range_check bitwise keccak

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256

// Generates a test vector for keccak256(encodedPacked(x, y)) and checks that the cairo implementation matches the expected results.
func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    alloc_locals;
    let (x_array: Uint256*) = alloc();
    let (y_array: Uint256*) = alloc();
    let (keccak_result_array: Uint256*) = alloc();

    local len: felt;

    %{
        import sha3
        import random
        from web3 import Web3
        def split_128(a):
            """Takes in value, returns uint256-ish tuple."""
            return [a & ((1 << 128) - 1), a >> 128]
        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr._reference_value+counter] = uint[0]
                memory[ptr._reference_value+counter+1] = uint[1]
                counter += 2
        def generate_n_bit_random(n):
            return random.randint(2**(n-1), 2**n - 1)

        # Implementation of solitidy keccak256(encodedPacked(x, y)) in python.
        def encode_packed_256_256(x_y):
            return int(Web3.solidityKeccak(["uint256", "uint256"], [x_y[0], x_y[1]]).hex(), 16)
        # Another implementation that uses sha3 directly and should be equal. 
        def keccak_256_256(x_y):
            k=sha3.keccak_256()
            k.update(x_y[0].to_bytes(32, 'big'))
            k.update(x_y[1].to_bytes(32, 'big'))
            return int.from_bytes(k.digest(), 'big')

        # Build Test vector [[x_1, y_1], [x_2, y_2], ..., [x_len, y_len]].

        # 256 random pairs of numbers, each pair having two random numbers of 1-256 bits.
        x_y_list = [[generate_n_bit_random(random.randint(1, 256)), generate_n_bit_random(random.randint(1, 256))] for _ in range(256)]
        # Adds 256 more pairs of equal bit length to the test vector.
        x_y_list += [[generate_n_bit_random(i), generate_n_bit_random(i)] for i in range(1,257)]

        keccak_output_list = [encode_packed_256_256(x_y) for x_y in x_y_list]
        keccak_result_list = [keccak_256_256(x_y) for x_y in x_y_list]

        # Sanity check on keccak implementations.
        assert all([keccak_output_list[i] == keccak_result_list[i] for i in range(len(keccak_output_list))])


        # Prepare x_array and y_array :
        x_array_split = [split_128(x_y[0]) for x_y in x_y_list]
        y_array_split = [split_128(x_y[1]) for x_y in x_y_list]
        # Write x_array : 
        write_uint256_array(ids.x_array, x_array_split)
        # Write y_array :
        write_uint256_array(ids.y_array, y_array_split)

        # Prepare keccak_result_array :
        keccak_result_list_split = [split_128(keccak_result) for keccak_result in keccak_result_list]
        # Write keccak_result_array :
        write_uint256_array(ids.keccak_result_array, keccak_result_list_split)

        # Write len :
        ids.len = len(keccak_result_list)
    %}

    test_keccak(
        x_array=x_array, y_array=y_array, keccak_result_array=keccak_result_array, index=len - 1
    );
    return ();
}

// Assert that uint256_reverse_endian(cairo_kecak(x[i], y[i])) == keccak_result_array[i] for all i in [0, index].
// Arguments:
// - x_array, y_array: pointers to arrays of uint256.
// - keccak_result_array: pointer to array of uint256.
// - index: the last index to check in the arrays.
func test_keccak{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    x_array: Uint256*, y_array: Uint256*, keccak_result_array: Uint256*, index: felt
) {
    alloc_locals;
    if (index == 0) {
        let (keccak_input: felt*) = alloc();
        let inputs_start = keccak_input;
        keccak_add_uint256{inputs=keccak_input}(num=x_array[index], bigend=1);
        keccak_add_uint256{inputs=keccak_input}(num=y_array[index], bigend=1);

        let (res_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
        let (res_keccak) = uint256_reverse_endian(res_keccak);

        assert 0 = res_keccak.low - keccak_result_array[index].low;
        assert 0 = res_keccak.high - keccak_result_array[index].high;
        return ();
    } else {
        let (keccak_input: felt*) = alloc();
        let inputs_start = keccak_input;
        keccak_add_uint256{inputs=keccak_input}(num=x_array[index], bigend=1);
        keccak_add_uint256{inputs=keccak_input}(num=y_array[index], bigend=1);

        let (res_keccak: Uint256) = keccak(inputs=inputs_start, n_bytes=2 * 32);
        let (res_keccak) = uint256_reverse_endian(res_keccak);

        assert 0 = res_keccak.low - keccak_result_array[index].low;
        assert 0 = res_keccak.high - keccak_result_array[index].high;
        return test_keccak(x_array, y_array, keccak_result_array, index - 1);
    }
}
