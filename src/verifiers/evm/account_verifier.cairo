from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak_bigend
from starkware.cairo.common.alloc import alloc
from src.types import ChainInfo
from packages.eth_essentials.lib.block_header import extract_state_root_little
from src.memorizers.evm import EvmHeaderMemorizer, EvmAccountMemorizer
from src.converter import le_address_chunks_to_felt

from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField

// Verifies the validity of all of the available account proofs and writes them to the memorizer
func verify_accounts{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_header_dict: DictAccess*,
    evm_account_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;
    local n_accounts: felt;
    %{ ids.n_accounts = len(batch["accounts"]) %}

    verify_accounts_inner(n_accounts, 0);

    return ();
}

func verify_accounts_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_header_dict: DictAccess*,
    evm_account_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_accounts: felt, index: felt) {
    alloc_locals;
    if (n_accounts == index) {
        return ();
    }

    let (address: felt*) = alloc();
    local key: Uint256;
    local key_leading_zeros: felt;
    %{
        from tools.py.utils import split_128, count_leading_zero_nibbles_from_hex, hex_to_int_array, nested_hex_to_int_array
        account = batch["accounts"][ids.index]
        ids.key_leading_zeros = count_leading_zero_nibbles_from_hex(account["account_key"])
        segments.write_arg(ids.address, hex_to_int_array(account["address"]))
        (key_low, key_high) = split_128(int(account["account_key"], 16))
        ids.key.low = key_low
        ids.key.high = key_high
    %}

    // Validate MPT key matches address
    let (hash: Uint256) = keccak_bigend(address, 20);
    assert key.low = hash.low;
    assert key.high = hash.high;

    local n_proofs: felt;
    %{ ids.n_proofs = len(account["proofs"]) %}

    verify_account(address, key, key_leading_zeros, n_proofs, 0);

    return verify_accounts_inner(n_accounts=n_accounts, index=index + 1);
}

func verify_account{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_header_dict: DictAccess*,
    evm_account_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(address: felt*, key: Uint256, key_leading_zeros: felt, n_proofs: felt, proof_idx: felt) {
    alloc_locals;
    if (proof_idx == n_proofs) {
        return ();
    }

    local block_number: felt;
    let (mpt_proof: felt**) = alloc();
    local proof_len: felt;
    let (proof_bytes_len: felt*) = alloc();

    %{
        proof = account["proofs"][ids.proof_idx]
        ids.block_number = proof["block_number"]
        segments.write_arg(ids.mpt_proof, nested_hex_to_int_array(proof["proof"]))
        segments.write_arg(ids.proof_bytes_len, proof["proof_bytes_len"])
        ids.proof_len = len(proof["proof"])
    %}

    // get state_root from verified headers
    let (header_rlp) = EvmHeaderMemorizer.get2(chain_id=chain_info.id, block_number=block_number);
    let state_root = HeaderDecoder.get_field(header_rlp, HeaderField.STATE_ROOT);

    let (rlp: felt*, value_len: felt) = verify_mpt_proof(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key,
        key_be_leading_zeroes_nibbles=key_leading_zeros,
        root=state_root,
        pow2_array=pow2_array,
    );

    let (felt_address) = le_address_chunks_to_felt(address);

    // add account to memorizer
    EvmAccountMemorizer.add(
        chain_id=chain_info.id, block_number=block_number, address=felt_address, rlp=rlp
    );

    return verify_account(
        address=address,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        proof_idx=proof_idx + 1,
    );
}
