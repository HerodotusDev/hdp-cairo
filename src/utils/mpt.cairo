from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.alloc import alloc
from packages.eth_essentials.lib.mpt import verify_mpt_proof as verify_mpt_proof_lib

// Wraps the original verify_mpt_proof function with the logic required for handling non-inclusion.
func verify_mpt_proof{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    mpt_proof: felt**,
    mpt_proof_bytes_len: felt*,
    mpt_proof_len: felt,
    key_be: Uint256,
    key_be_leading_zeroes_nibbles: felt,
    root: Uint256,
    pow2_array: felt*,
) -> (value: felt*, value_len: felt) {
    let (root_le) = uint256_reverse_endian(root);
    let (rlp: felt*, value_len: felt) = verify_mpt_proof_lib(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=mpt_proof_bytes_len,
        mpt_proof_len=mpt_proof_len,
        key_be=key_be,
        key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
        root=root_le,
        pow2_array=pow2_array,
    );

    // handle non-inclusion case
    if (value_len == -1) {
        let (res: felt*) = alloc();
        assert res[0] = 0x80;
        return (value=res, value_len=1);
    } else {
        return (value=rlp, value_len=value_len);
    }
}
