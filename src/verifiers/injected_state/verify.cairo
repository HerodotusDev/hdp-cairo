from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, KeccakBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, uint256_to_felt
from starkware.cairo.common.default_dict import default_dict_finalize
from starkware.cairo.common.registers import get_label_location
from src.memorizers.injected_state.memorizer import InjectedStateMemorizer
from src.utils.patricia_with_keccak import patricia_update
from src.utils.keccak import TruncatedKeccak, finalize_truncated_keccak
from src.verifiers.mpt import HashNodeTruncatedKeccak, traverse
from src.types import TrieNode

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
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
}() -> (root: felt, value: felt){
    alloc_locals;
    
    local key_be: felt; 
    %{ ids.key_be = state_proof_wrapper.leaf.key %} 
    
    let (proof_bytes_len: felt*) = alloc();
    %{ segments.write_arg(ids.proof_bytes_len, state_proof.inclusion.proof_bytes_len) %}

    tempvar proof_len: felt = nondet %{ len(state_proof) %};

    let (nodes_ptr: felt**) = alloc();
    // %{ trie_node_proof = state_proofs %}
    %{ segments.write_arg(ids.nodes_ptr, state_proofs) %}

    let (hash_binary_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_binary_node);
    let (hash_edge_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_edge_node);

    let (keccak_ptr_seg: TruncatedKeccak*) = alloc();
    local keccak_ptr_seg_start: TruncatedKeccak* = keccak_ptr_seg;
    let hash_ptr = cast(keccak_ptr_seg, HashBuiltin*);
    // local keccak_ptr_seg_start: HashBuiltin* = cast(keccak_ptr_seg, HashBuiltin*);
    
    let (root, value) = traverse{
        hash_binary_node_ptr=hash_binary_node_ptr, hash_edge_node_ptr=hash_edge_node_ptr, hash_ptr=hash_ptr,
        bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(
        cast(nodes_ptr, TrieNode**), proof_len, key_be
    );


    with keccak_ptr_seg{
        finalize_truncated_keccak{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(ptr_start=keccak_ptr_seg_start, ptr_end=keccak_ptr_seg);
    }


    with keccak_ptr_seg{
        finalize_truncated_keccak{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(ptr_start=keccak_ptr_seg_start, ptr_end=keccak_ptr_seg);
    }

    if (value == 0) {
        //non inclusion proof case -> handle it
    } 

    return (root=root, value=value);
    //todo()! -> memorizer, save the keys
}

func non_inclusion_state_verification(
    injected_state_memorizer: DictAccess*,
) -> (value: felt*, value_len: felt){
    alloc_locals;

    // todo!();
    assert 1 = 0;
    let (res: felt*) = alloc();
    return (value=res, value_len=0);
}

func update_state_verification(
    injected_state_memorizer: DictAccess*,
) -> (value: felt*, value_len: felt){
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