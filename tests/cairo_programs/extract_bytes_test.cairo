%builtins output range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin

from src.libs.utils import pow2alloc127
from src.libs.rlp_little import extract_n_bytes_at_pos, extract_n_bytes_from_le_64_chunks_array

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let (pow2_array: felt*) = pow2alloc127();
    test_extract_n_bytes_from_word(n=128, pow2_array=pow2_array);
    test_extract_n_bytes_from_array(n=100, pow2_array=pow2_array);

    %{ print("End tests!") %}
    return ();
}

func test_extract_n_bytes_from_word{bitwise_ptr: BitwiseBuiltin*}(n: felt, pow2_array: felt*) {
    alloc_locals;
    let (pow2_array: felt*) = pow2alloc127();
    let (test_words: felt*) = alloc();
    let (pos: felt*) = alloc();
    let (n_bytes: felt*) = alloc();
    let (expected: felt*) = alloc();
    %{
        import random
        random.seed(0)
        test_words = [random.randint(0, 2**64-1) for _ in range(ids.n)]

        pos = [random.randint(0, 7) for _ in range(ids.n)]
        n_bytes = [random.randint(0, 8-pos) for pos in pos]

        def extract_n_bytes_from_word(word, pos, n):
            # Mask to extract the desired bytes
            mask = (1 << (n * 8)) - 1
            # Shift the word right to align the desired bytes at the end, then apply the mask
            extracted_bytes = (word >> (pos * 8)) & mask
            return extracted_bytes

        expected = [extract_n_bytes_from_word(word, pos, n_bytes) for word, pos, n_bytes in zip(test_words, pos, n_bytes)]
        segments.write_arg(ids.test_words,test_words)
        segments.write_arg(ids.pos,pos)
        segments.write_arg(ids.n_bytes,n_bytes)
        segments.write_arg(ids.expected,expected)
    %}

    test_extract_n_bytes_from_word_inner(
        index=0,
        n_words=n,
        words=test_words,
        pos=pos,
        n_bytes=n_bytes,
        expected=expected,
        pow2_array=pow2_array,
    );
    return ();
}
func test_extract_n_bytes_from_word_inner{bitwise_ptr: BitwiseBuiltin*}(
    index: felt,
    n_words: felt,
    words: felt*,
    pos: felt*,
    n_bytes: felt*,
    expected: felt*,
    pow2_array: felt*,
) {
    alloc_locals;
    if (index == n_words) {
        return ();
    } else {
        let bytes = extract_n_bytes_at_pos(
            word_64_little=words[index], pos=pos[index], n=n_bytes[index], pow2_array=pow2_array
        );
        let expected_val = expected[index];
        %{ print(f"expected : {hex(ids.expected_val)}, bytes : {hex(ids.bytes)}") %}
        assert 0 = bytes - expected_val;
        return test_extract_n_bytes_from_word_inner(
            index=index + 1,
            n_words=n_words,
            words=words,
            pos=pos,
            n_bytes=n_bytes,
            expected=expected,
            pow2_array=pow2_array,
        );
    }
}

func test_extract_n_bytes_from_array{range_check_ptr}(n: felt, pow2_array: felt*) {
    alloc_locals;
    let (test_arrays: felt**) = alloc();
    let (start_words: felt*) = alloc();
    let (start_offsets: felt*) = alloc();
    let (n_bytes_to_extract: felt*) = alloc();
    let (expected: felt**) = alloc();
    let (expected_len: felt*) = alloc();
    %{
        import random
        from random import randint as rint
        from tools.py.utils import bytes_to_8_bytes_chunks, bytes_to_8_bytes_chunks_little
        random.seed(0)

        # n arrays consisting of random words of 64 bits
        test_arrays = [[rint(0, 2**64-1) for _ in range(rint(1,64))] for _ in range(ids.n)]
        # Add a random word of random byte size between 1 and 8 to each array
        test_arrays = [arr + [rint(1, 2**(rint(1,8)*8)-1)] for arr in test_arrays]

        def min_bytes_to_represent_int(x:int):
            return (x.bit_length() + 7) // 8
        def merge_integers_to_bytes(int_array):
            merged_bytes = bytearray()
            # Process all integers except the last one
            for number in int_array[:-1]:
                # Convert each integer to a byte array of fixed 8 bytes and append
                merged_bytes.extend(number.to_bytes(8, "big"))
            # Process the last integer
            if int_array:
                last_number = int_array[-1]
                num_bytes = min_bytes_to_represent_int(last_number)
                merged_bytes.extend(last_number.to_bytes(num_bytes, "big"))
            return bytes(merged_bytes)


        test_arrays_bytes = [merge_integers_to_bytes(arr) for arr in test_arrays]
        start_words = [rint(0, len(arr) - 1) for arr in test_arrays]
        start_offsets = []
        for (i, arr) in enumerate(test_arrays):
            if start_words[i] == len(arr) - 1:
                if min_bytes_to_represent_int(arr[-1]) - 1 == -1:
                    print(f"arr[-1] : {arr[-1]}]")
                    raise Exception("min_bytes_to_represent_int(arr[-1]) - 1 == -1")
                else:
                    # print(f"min_bytes_to_represent_int(arr[-1]) - 1 : {min_bytes_to_represent_int(arr[-1]) - 1}")
                    start_offsets.append(rint(0, min_bytes_to_represent_int(arr[-1]) - 1))
            else:
                start_offsets.append(rint(0, 7))
                
        n_bytes = [rint(1, len(test_arr_bytes) - (start_word * 8 + start_offset)) for test_arr_bytes, start_word, start_offset in zip(test_arrays_bytes, start_words, start_offsets)]

        def extract_n_bytes_from_array(bytes_array, start_word, start_offset, n_bytes_to_extract):
            start_byte = start_word * 8 + start_offset
            end_byte = start_byte + n_bytes_to_extract
            res_bytes = bytes_array[start_byte:end_byte]
            res_array = bytes_to_8_bytes_chunks_little(res_bytes)
            return res_array            

        test_arrays_little =  [bytes_to_8_bytes_chunks_little(x) for x in test_arrays_bytes]
        expected = [extract_n_bytes_from_array(array, start_word, start_offset, n_bytes) for array, start_word, start_offset, n_bytes in zip(test_arrays_bytes, start_words, start_offsets, n_bytes)]
        segments.write_arg(ids.test_arrays, test_arrays_little)
        segments.write_arg(ids.start_words, start_words)
        segments.write_arg(ids.start_offsets, start_offsets)
        segments.write_arg(ids.n_bytes_to_extract, n_bytes)
        segments.write_arg(ids.expected, expected)
        segments.write_arg(ids.expected_len, [len(arr) for arr in expected])

        print([len(test_array) for test_array in test_arrays])
        print(f"Test arrays : {[[hex(x) for x in arr] for arr in test_arrays_little]}")
        print(f"N_bytes : {n_bytes}")
        print(f"Start words : {start_words}")
        print(f"Start offsets : {start_offsets}")
        print(f"Expected : {expected}")
    %}

    test_extract_n_bytes_from_array_inner(
        index=0,
        n_tests=n,
        arrays=test_arrays,
        start_words=start_words,
        start_offsets=start_offsets,
        n_bytes=n_bytes_to_extract,
        expected=expected,
        expected_len=expected_len,
        pow2_array=pow2_array,
    );

    return ();
}

func test_extract_n_bytes_from_array_inner{range_check_ptr}(
    index: felt,
    n_tests: felt,
    arrays: felt**,
    start_words: felt*,
    start_offsets: felt*,
    n_bytes: felt*,
    expected: felt**,
    expected_len: felt*,
    pow2_array: felt*,
) {
    alloc_locals;
    if (index == n_tests) {
        %{ print("End test") %}
        return ();
    } else {
        // %{
        //     print(f"Test array little : {test_arrays_little[ids.index]} len : {len(test_arrays_little[ids.index])}")
        //     print(f"Expected : {expected[ids.index]} len : {len(expected[ids.index])}")
        // %}
        let expected_array = expected[index];
        let (result, result_len) = extract_n_bytes_from_le_64_chunks_array(
            array=arrays[index],
            start_word=start_words[index],
            start_offset=start_offsets[index],
            n_bytes=n_bytes[index],
            pow2_array=pow2_array,
        );
        assert result_len - expected_len[index] = 0;
        assert_array_rec(expected_array, result, 0, result_len);
        %{ print(f"Pass {ids.index+1}/{ids.n_tests} ! \n") %}
        return test_extract_n_bytes_from_array_inner(
            index + 1,
            n_tests,
            arrays,
            start_words,
            start_offsets,
            n_bytes,
            expected,
            expected_len,
            pow2_array,
        );
    }
}

// Recursively asserts that arrays x and y are equal at all indices up to index.
func assert_array_rec(x: felt*, y: felt*, index: felt, len: felt) {
    if (index == len) {
        return ();
    } else {
        assert x[index] = y[index];
        return assert_array_rec(x, y, index + 1, len);
    }
}
