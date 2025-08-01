from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, KeccakBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, uint256_to_felt
from starkware.cairo.common.default_dict import default_dict_finalize
from packages.eth_essentials.lib.mpt import verify_mpt_proof as verify_mpt_proof_lib
from src.memorizers.injected_state.memorizer import InjectedStateMemorizer
from src.utils.patricia_with_keccak import patricia_update

// Wraps the MPT library function to handle non-inclusion proofs gracefully.
// If the library function indicates non-inclusion (returns value_len = -1),
// this wrapper returns a pointer to RLP-encoded null (0x80) and length 1.
// Otherwise, it returns the RLP data and length provided by the library.
// Args:
//   (Same as verify_mpt_proof_lib, except root is expected in Big Endian)
//   root: The MPT root hash (Uint256, Big Endian).
// Returns:
//   value: Pointer to the RLP-encoded value (or [0x80] for non-inclusion).
//   value_len: Length of the RLP value (1 for non-inclusion).

func inclusion_state_verification{
    range_check_ptr,
    keccak_ptr: KeccakBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
}() -> (value: felt*, value_len: felt){
    alloc_locals;
    
    %{ inclusion = state_proof_wrapper.state_proof.inclusion %}

    local key_be: Uint256;
    %{ ids.key_be = state_proof_wrapper.leaf.key %}
    local root: Uint256;
    %{ ids.root = state_proof_wrapper.root_hash %}
    
    tempvar key_be_leading_zeroes_nibbles: felt = nondet %{ len(key_be.lstrip("0x")) - len(key_be.lstrip("0x").lstrip("0")) %};

    let (proof_bytes_len: felt*) = alloc();
    %{ segments.write_arg(ids.proof_bytes_len, inclusion.proof_bytes_len) %}

    let (proof_len: felt) = alloc();
    %{ memory[ap] = to_felt_or_relocatable(len(inclusion)) %}

    let (mpt_proof: felt**) = alloc();
    %{ segments.write_arg(ids.mpt_proof, [int(x, 16) for x in ]) %}

    // Call the underlying MPT verification library function
    let (rlp: felt*, value_len: felt) = verify_mpt_proof_lib(
        mpt_proof=mpt_proof,
        mpt_proof_bytes_len=proof_bytes_len,
        mpt_proof_len=proof_len,
        key_be=key_be,
        key_be_leading_zeroes_nibbles=key_be_leading_zeroes_nibbles,
        root=root,
        pow2_array=pow2_array,
    );

    // Handle non-inclusion case signaled by the library
    if (value_len == -1) {
        // Allocate memory for RLP null (0x80)
        let (res: felt*) = alloc();
        assert res[0] = 0x80;
        // Return pointer to [0x80] and length 1
        return (value=res, value_len=1);
    } else {
        // Inclusion proof successful, return the RLP data and its length
        return (value=rlp, value_len=value_len);
    }

    //todo()! -> memorizer, save the keys
}

func non_inclusion_state_verification() -> (value: felt*, value_len: felt){
    alloc_locals;

    // todo!();
    assert 1 = 0;
    let (res: felt*) = alloc();
    return (value=res, value_len=0);
}

func update_state_verification() -> (value: felt*, value_len: felt){
    alloc_locals;

    %{ update = state_proof_wrapper.state_proof.update %}
    // tempvar key_be: Uint256 = nondet %{ state_proof_wrapper.leaf.key %}; 
    // tempvar prev_root: Uint256 = nondet %{ update.0 %}; //shouldnt this be the stateproofwrapper so we can get the root 
    // tempvar new_root: Uint256 = nondet %{ update.1 %}; 

    //todo()!
    assert 1 = 0;
    let (res: felt*) = alloc();
    return (value=res, value_len=0);
}