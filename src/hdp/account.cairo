from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.libs.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from src.hdp.types import Account, AccountProof, Header, AccountState, AccountSlot, AccountSlotProof
from src.libs.block_header import extract_state_root_little
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.libs.utils import felt_divmod
from src.hdp.utils import keccak_hash_array_to_uint256, uint_le_u64_array_to_uint256
from src.hdp.memorizer import HeaderMemorizer

// Initializes the accounts, ensuring that the passed address matches the key.
// Params:
// - accounts: empty accounts array that the accounts will be writte too.
// - n_accounts: the number of accounts to initialize.
// - index: the current index of the account being initialized.
func populate_account_segments{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(accounts: Account*, n_accounts: felt, index: felt) {
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

        return populate_account_segments(
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
// - pow2_array: the array of powers of 2.
func verify_n_accounts{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    headers: Header*,
    header_dict: DictAccess*,
} (
    accounts: Account*,
    accounts_len: felt,
    accounts_states: AccountState**,
    pow2_array: felt*,
) {
    alloc_locals;
    if(accounts_len == 0) {
        return ();
    }

    let account_idx = accounts_len - 1;


    // Question: 
    // Am I supposed to allocate the account_states here? I am not able to make it work without another alloc, but I wonder if im wasting memory here, since I allocated the nested structure already in hdp
    let account_states: AccountState* = alloc();
    
    let states = verify_account(
        account=accounts[account_idx],
        account_states=account_states,
        proof_idx=0,
        pow2_array=pow2_array,
    );
 
    assert accounts_states[account_idx] = states;

    return verify_n_accounts(
        accounts=accounts,
        accounts_len=accounts_len - 1,
        accounts_states=accounts_states,
        pow2_array=pow2_array,
    );
}

// Verifies the validity of an account's account_proofs
// Params:
// - account: the account to verify.
// - proof_idx: the index of the proof to verify.
// - pow2_array: the array of powers of 2.
func verify_account{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*, 
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    headers: Header*,
    header_dict: DictAccess*,
} (
    account: Account,
    account_states: AccountState*,
    proof_idx: felt,
    pow2_array: felt*,
) -> AccountState* {
    alloc_locals;
    if (proof_idx == account.proofs_len) {
        return account_states;
    }

    // get state_root from verified headers
    let header = HeaderMemorizer.get(account.proofs[proof_idx].block_number);
    let state_root = extract_state_root_little(headers[proof_idx].rlp);

    %{
        print("stateRoot.high", hex(ids.state_root.high))
        print("stateRoot.low", hex(ids.state_root.low))
    %}

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

    // write verified account state
    assert account_states[proof_idx] = AccountState(
        values=value,
        values_len=value_len,
    );

    return verify_account(
        account=account,
        account_states=account_states,
        proof_idx=proof_idx + 1,
        pow2_array=pow2_array,
    );
}

// retrieves the account nonce from rlp encoded account state
func get_account_nonce{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*) -> Uint256 {
    alloc_locals;
    let (res, res_len, bytes_len) = decode_account_value(rlp=rlp, value_idx=0, item_starts_at_byte=2, counter=0);

    let result = uint_le_u64_array_to_uint256(
        elements=res,
        elements_len=res_len,
        bytes_len=bytes_len
    );

    %{
        print("nonce.high", ids.result.high)
        print("nonce.low", ids.result.low)
    %}

    return result;
}

// retrieves the account balance from rlp encoded account state
func get_account_balance{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*) -> Uint256 {
    alloc_locals;

    let (res, res_len, bytes_len) = decode_account_value(rlp=rlp, value_idx=1, item_starts_at_byte=2, counter=0);

    let result = uint_le_u64_array_to_uint256(
        elements=res,
        elements_len=res_len,
        bytes_len=bytes_len
    );

    %{  
        print("balance.high", ids.result.high)
        print("balance.low", ids.result.low)
    %}

    return result;
}

// retrieves the account state root from rlp encoded account state
func get_account_state_root{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*) -> Uint256 {
    alloc_locals;

    let (res, res_len, _byte_len) = decode_account_value(rlp=rlp, value_idx=2, item_starts_at_byte=2, counter=0);

    let result = keccak_hash_array_to_uint256(
        elements=res,
        elements_len=res_len
    );

    %{
        print("stateRoot.high", hex(ids.result.high))
        print("stateRoot.low", hex(ids.result.low))
    %}

    return result;
}

// retrieves the account code hash from rlp encoded account state
func get_account_code_hash{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*) -> Uint256 {
    alloc_locals;

    let (res, res_len, _byte_len) = decode_account_value(rlp=rlp, value_idx=3, item_starts_at_byte=2, counter=0);

    let result = keccak_hash_array_to_uint256(
        elements=res,
        elements_len=res_len
    );

    %{
        print("codehash.high", hex(ids.result.high))
        print("codehash.low", hex(ids.result.low))
    %}

    return result;
}

// function for decoding account values from rlp encoded account state
// this function does not check for the validity of the rlp encoding, as this was already done in the mpt proof verification
// Params:
// - rlp: the rlp encoded account state
// - value_idx: the index of the value to retrieve (nonce, balance, stateRoot, codeHash) as index
// - item_starts_at_byte: the byte at which the item starts. Since the two hashes are 32 bytes long, we know the list is going to be long, so we can skip the first 2 bytes
// - counter: the current counter of the recursive function
// Returns: LE 4bytes array of the value + the length of the array
func decode_account_value{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*, value_idx: felt, item_starts_at_byte: felt, counter: felt) -> (res: felt*, res_len: felt, bytes_len: felt) {
    alloc_locals;

    // %{
    //     print("Iteration: ", ids.counter)
    //     print("item_starts_at_byte", ids.item_starts_at_byte)
    // %}

    let (item_starts_at_word, item_start_offset) = felt_divmod(
        item_starts_at_byte, 8
    );

    // %{
    //     print("item_starts_at_word", ids.item_starts_at_word)
    //     print("item_start_offset", ids.item_start_offset)
    // %}

    let current_item = extract_byte_at_pos(
        rlp[item_starts_at_word],
        item_start_offset,
        pow2_array
    );

    // %{
    //     print("current_item", hex(ids.current_item))
    // %}

    local item_has_prefix: felt;

    // We need to validate this hint via assert!!!
    %{
        # print("current_item", hex(ids.current_item))
        if ids.current_item < 0x80:
            ids.item_has_prefix = 0
        else:
            ids.item_has_prefix = 1
    %}

    local current_item_len: felt;

    if (item_has_prefix == 1) {
        assert [range_check_ptr] = current_item - 0x80; // validates item_has_prefix hint
        current_item_len = current_item - 0x80;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len + 1;
    } else {
        assert [range_check_ptr] = 0x7f - current_item; // validates item_has_prefix hint
        current_item_len = 1;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len;
    }

    let range_check_ptr = range_check_ptr + 1;
    

    // %{ print("next_item_starts_at_byte", ids.next_item_starts_at_byte) %}

    if (value_idx == counter) {
        // handle empty bytes case
        if(current_item_len == 0) {
            // %{ print("empty case") %}
            let (res: felt*) = alloc();
            assert res[0] = 0;
            return (res=res, res_len=1, bytes_len=1);
        } 

        // handle prefix case
        if (item_has_prefix == 1) {
            // %{ print("prefix case") %}
            let (word_idx, offset) = felt_divmod(
                item_starts_at_byte + 1, 8
            );
            
            let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
                array=rlp,
                start_word=word_idx,
                start_offset=offset,
                n_bytes=current_item_len,
                pow2_array=pow2_array
            );

            return (res=res, res_len=res_len, bytes_len=current_item_len);
        } else {
            // %{ print("single byte case") %}
            // handle single byte case
            let (res: felt*) = alloc();
            assert res[0] = current_item;
            return (res=res, res_len=1, bytes_len=1);
        }
    }

    return decode_account_value(
        rlp=rlp,
        value_idx=value_idx,
        item_starts_at_byte=next_item_starts_at_byte,
        counter=counter+1,
    );
}