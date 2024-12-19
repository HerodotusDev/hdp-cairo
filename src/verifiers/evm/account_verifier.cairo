from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from src.utils.mpt import verify_mpt_proof
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak_bigend
from starkware.cairo.common.alloc import alloc
from src.types import ChainInfo
from packages.eth_essentials.lib.block_header import extract_state_root_little
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams
from src.utils.converter import le_address_chunks_to_felt
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField

// Verifies the validity of all of the available account proofs and writes them to the memorizer
func verify_accounts{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;

    tempvar n_accounts: felt = nondet %{ len(batch.accounts) %};
    verify_accounts_inner(n_accounts, 0);

    return ();
}

func verify_accounts_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_accounts: felt, idx: felt) {
    alloc_locals;
    if (n_accounts == idx) {
        return ();
    }

    let (address: felt*) = alloc();
    %{
        account = batch.accounts[ids.idx]
        segments.write_arg(ids.address, [int(x, 16) for x in account.address]))
    %}

    local key: Uint256;
    %{
        from tools.py.utils import split_128
        (ids.key.low, ids.key.high) = split_128(int(account.account_key, 16))
    %}

    local key_leading_zeros: felt;
    %{ ids.key_leading_zeros = len(account.account_key.lstrip("0x")) - len(account.account_key.lstrip("0x").lstrip("0")) %}

    // Validate MPT key matches address
    let (hash: Uint256) = keccak_bigend(address, 20);
    assert key.low = hash.low;
    assert key.high = hash.high;

    let (felt_address) = le_address_chunks_to_felt(address);

    tempvar n_proofs: felt = nondet %{ len(account.proofs) %};
    verify_account(
        address=felt_address, key=key, key_leading_zeros=key_leading_zeros, n_proofs=n_proofs, idx=0
    );

    return verify_accounts_inner(n_accounts=n_accounts, idx=idx + 1);
}

func verify_account{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    evm_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(address: felt, key: Uint256, key_leading_zeros: felt, n_proofs: felt, idx: felt) {
    alloc_locals;
    if (idx == n_proofs) {
        return ();
    }

    %{ proof = account.proofs[ids.idx] %}
    tempvar proof_len: felt = nondet %{ len(proof.proof) %};
    tempvar block_number: felt = nondet %{ proof.block_number %};

    let (proof_bytes_len: felt*) = alloc();
    %{ segments.write_arg(ids.proof_bytes_len, proof.proof_bytes_len) %}

    let (mpt_proof: felt**) = alloc();
    %{ segments.write_arg(ids.mpt_proof, [int(x, 16) for x in proof.proof]) %}

    // get state_root from verified headers
    let memorizer_key = EvmHashParams.header(chain_id=chain_info.id, block_number=block_number);
    let (header_rlp) = EvmMemorizer.get(key=memorizer_key);
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

    // add account to memorizer
    let memorizer_key = EvmHashParams.account(
        chain_id=chain_info.id, block_number=block_number, address=address
    );
    EvmMemorizer.add(key=memorizer_key, data=rlp);

    return verify_account(
        address=address,
        key=key,
        key_leading_zeros=key_leading_zeros,
        n_proofs=n_proofs,
        idx=idx + 1,
    );
}
