from src.libs.mpt import verify_mpt_proof
from src.hdp.types import AccountProof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin


func verify_account_proofs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
} (
    mpt_account_proofs: felt***,
    mpt_account_proofs_bytes_len: felt**,
    account_proofs: AccountProof*,
    keys_little: Uint256*,
    hashes_to_assert: Uint256,
    account_proofs_len: felt,
    pow2_array: felt*,
) {
    if (account_proofs_len == 0) {
        return ();
    }

    let account_idx = account_proofs_len - 1;

    %{
        print(ids.account_idx)
        
    %}




    let (value: felt*, value_len: felt) = verify_mpt_proof(
        mpt_proof=mpt_account_proofs[account_idx],
        mpt_proof_bytes_len=mpt_account_proofs_bytes_len[account_idx],
        mpt_proof_len=account_proofs[account_idx].proof_len,
        key_little=keys_little[account_idx],
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=hashes_to_assert,
        pow2_array=pow2_array,
    );

    return verify_account_proofs(
        mpt_account_proofs=mpt_account_proofs,
        mpt_account_proofs_bytes_len=mpt_account_proofs_bytes_len,
        account_proofs=account_proofs,
        keys_little=keys_little,
        hashes_to_assert=hashes_to_assert,
        account_proofs_len=account_idx,
        pow2_array=pow2_array,
    );
}


// func verify_mpt_proof{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
//     mpt_proof: felt**,
//     mpt_proof_bytes_len: felt*,
//     mpt_proof_len: felt, x
//     key_little: Uint256, x
//     n_nibbles_already_checked: felt,
//     node_index: felt,
//     hash_to_assert: Uint256,
//     pow2_array: felt*,
// ) -> (value: felt*, value_len: felt) {