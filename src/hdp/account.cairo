from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import Account, AccountProof, HeaderProof
from src.libs.block_header import extract_state_root_little

// Initializes the accounts, ensuring that the passed address matches the key.
// Params:
// - accounts: empty accounts array that the accounts will be writte too.
// - n_accounts: the number of accounts to initialize.
// - index: the current index of the account being initialized.
func init_accounts{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(accounts: Account*, n_accounts: felt, index: felt) {
    alloc_locals;
    if (index == n_accounts) {
        return ();
    } else {
        local account: Account;
        let (proofs: AccountProof*) = alloc();
        
        %{
            def write_account(account_ptr, proofs_ptr, account):
                memory[account_ptr._reference_value] = segments.gen_arg(account["address"])
                memory[account_ptr._reference_value + 1] = account["key"]["low"]
                memory[account_ptr._reference_value + 2] = account["key"]["high"]
                memory[account_ptr._reference_value + 3] = len(account["proofs"])
                memory[account_ptr._reference_value + 4] = proofs_ptr._reference_value

            def write_proofs(ptr, proofs):
                offset = 0
                for proof in proofs:
                    memory[ptr._reference_value + offset] = proof["block_number"]
                    memory[ptr._reference_value + offset + 1] = len(proof["proof"])
                    memory[ptr._reference_value + offset + 2] = segments.gen_arg(proof["proof_bytes_len"])
                    memory[ptr._reference_value + offset + 3] = segments.gen_arg(proof["proof"])
                    offset += 4

            account = program_input['header_batches'][0]["accounts"][ids.index]

            write_proofs(ids.proofs, account["proofs"])
            write_account(ids.account, ids.proofs, account)
        %}

        // ensure that address matches the key
        let (hash: Uint256) = keccak(account.address, 20);
        assert account.key.low = hash.low;
        assert account.key.high = hash.high;

        assert accounts[index] = account;


        return init_accounts(
            accounts=accounts,
            n_accounts=n_accounts,
            index=index + 1,
        );
    }
}

// Verifies the validity of all of the accounts account_proofs
// Params:
// - accounts: the accounts to verify.
// - accounts_len: the number of accounts to verify.
// - hashes_to_assert: the hash to assert. Currently this is hardcoded to goerli#10453879
// - pow2_array: the array of powers of 2.
func verify_n_accounts{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    header_proofs: HeaderProof*,
} (
    accounts: Account*,
    accounts_len: felt,
    pow2_array: felt*,
) {
    if(accounts_len == 0) {
        return ();
    }

    let account_idx = accounts_len - 1;

    verify_account(
        account=accounts[account_idx],
        proof_idx=0,
        pow2_array=pow2_array,
    );

    return verify_n_accounts(
        accounts=accounts,
        accounts_len=accounts_len - 1,
        pow2_array=pow2_array,
    );
}

// Verifies the validity of an account's account_proofs
// Params:
// - account: the account to verify.
// - proof_idx: the index of the proof to verify.
// - hashes_to_assert: state_root of the proof. Currently hardcoded to goerli#10453879
// - pow2_array: the array of powers of 2.
func verify_account{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    header_proofs: HeaderProof*,
} (
    account: Account,
    proof_idx: felt,
    pow2_array: felt*,
) {
    if (proof_idx == account.proofs_len) {
        return ();
    }
    let state_root = extract_state_root_little(header_proofs[proof_idx].rlp_encoded_header);

    let (value: felt*, value_len: felt) = verify_mpt_proof(
        mpt_proof=account.proofs[proof_idx].proof,
        mpt_proof_bytes_len=account.proofs[proof_idx].proof_bytes_len,
        mpt_proof_len=account.proofs[proof_idx].proof_len,
        key_little=account.key,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root,
        pow2_array=pow2_array,
    );

    return verify_account(
        account=account,
        proof_idx=proof_idx + 1,
        pow2_array=pow2_array,
    );
}