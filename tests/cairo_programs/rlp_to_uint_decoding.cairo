%builtins range_check bitwise keccak
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_eq, uint256_reverse_endian
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.rlp import le_u64_array_to_uint256, decode_rlp_word_to_uint256
from packages.evm_libs_cairo.lib.utils import pow2alloc127

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc127();
    local decode_rlp_word_to_uint256_len: felt;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
            uint256_reverse_endian,
            split_128,
            reverse_endian,
            bytes_to_8_bytes_chunks,
        )
        import rlp

        # Test cases for decode_rlp_word_to_uint256 at every byte length
        decode_rlp_word_to_uint256 = [
            0x66,
            0x9388,
            0xae5e8a,
            0x4e98ca05,
            0x61cb9c7ce6,
            0x7211a2516f35,
            0x58b5d8b3f67446,
            0x7519e8621ea1a3ee,
            0x9ee2e781a323050f12,
            0xae45d19ed5310e62f4f3,
            0xf3fc1e528b85432aab4d45,
            0x43bc24aed589d97fae233712,
            0x97f3eab6553c2f284d04e314bd,
            0xb5f421d6740127fafbb0a89a8bc3,
            0x59309a988582ff574bd3ed9a4bd6ce,
            0x696b085c5dc084660c1903ed46d07456,
            0x895613670f5cedbba5d22dc9dc9e47fe1d,
            0xc33d466640180017ddeb18aacde8790775fd,
            0x4e6184f5eae2a03db9aeb583ec012b310894fc,
            0x183311ee3de03a9fdf7e30da707cea7842344095,
            0xa5a0abe55971873d59c8eacc1b0e3dc75d041a0560,
            0x8966bfd6beb8ad6f93bdaf78b87d8e0b7a0d55cb6608,
            0x65f51a126b8b9168089697ad4a978861a1df6ac779d8f2,
            0x719a99b4d93f830e3a12d8b21d8406bf673ededb3d74f835,
            0x7fb90265c0558fda3544677e3ac6bee21be6b0666686e8e886,
            0xd485c055420d72665e38f63657eeff26ea7a4cf658ad90ec433a,
            0xf427f5d9e55db2ca6cbc480c58ef030f1f9f3989e99b35c8ae176e,
            0xb39e496e6b029417ae37d000b3b86427e5bb366a738c3b1268ea15ff,
            0x938f32171b29d0e29d347e283edb0749d43dafcbff79cafc08f6e936c4,
            0x5a8fdd9d1017e051bda2cf1d27518c38714f0659dd8c362840f0aacf0b46,
            0x85bdc29d6de8c62e3c3a7789448dfa47cc2ad137791dcb6f7413fc1e347734,
            0x66ba7c97a8d86016687269a255b6557ae499a417222aede48aca47e8a34fccc8
        ]

        ids.decode_rlp_word_to_uint256_len = len(decode_rlp_word_to_uint256)
    %}

    test_decode_rlp_word_to_uint256{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(decode_rlp_word_to_uint256_len, 0);

    return ();
}

func test_decode_rlp_word_to_uint256{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(case_len: felt, index: felt) {
    if (index == case_len) {
        return ();
    }
    test_decode_rlp_word_to_uint256_inner{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(case=index);

    return test_decode_rlp_word_to_uint256(case_len=case_len, index=index + 1);
}

func test_decode_rlp_word_to_uint256_inner{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(case: felt) {
    alloc_locals;

    let (chunks: felt*) = alloc();
    local expected_le: Uint256;
    local expected_be: Uint256;
    local bytes_len: felt;

    %{
        # Writes input and expected value to cairo
        def write_case_values(value):
            (low_be, high_be) = split_128(value)
            ids.expected_be.low = low_be
            ids.expected_be.high = high_be

            reversed_value = uint256_reverse_endian(value)
            (low_le, high_le) = split_128(reversed_value)
            ids.expected_le.low = low_le
            ids.expected_le.high = high_le

            rlp_value = rlp.encode(value)
            ids.bytes_len = len(rlp_value)
            chunks = bytes_to_8_bytes_chunks_little(rlp_value)
            segments.write_arg(ids.chunks, chunks)  

        write_case_values(decode_rlp_word_to_uint256[ids.case])
    %}

    let result_le = decode_rlp_word_to_uint256(chunks, bytes_len);
    let (local result_be) = uint256_reverse_endian(result_le);

    // %{
    //     print(f"Expect: {hex(ids.expected_le.low)} {hex(ids.expected_le.high)}")
    //     print(f"Result: {hex(ids.result_le.low)} {hex(ids.result_le.high)}")
    // %}
    assert expected_le.low = result_le.low;
    assert expected_le.high = result_le.high;

    assert expected_be.low = result_be.low;
    assert expected_be.high = result_be.high;

    return ();
}
