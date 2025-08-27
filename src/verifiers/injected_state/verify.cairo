from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, KeccakBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, uint256_to_felt
from starkware.cairo.common.default_dict import default_dict_finalize
from starkware.cairo.common.registers import get_label_location
from src.utils.patricia_with_keccak import patricia_update_using_update_constants, patricia_update_constants_new
from src.utils.keccak import TruncatedKeccak, finalize_truncated_keccak
from src.verifiers.mpt import HashNodeTruncatedKeccak, traverse
from src.types import TrieNode

func inclusion_state_verification{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
}() -> (root: felt, key: felt, value: felt){
    alloc_locals;

    tempvar key_be: felt = nondet %{ state_proof_read.leaf.key %};
    tempvar proof_len: felt = nondet %{ len(state_proof) %};

    let (nodes_ptr: felt**) = alloc();
    %{ segments.write_arg(ids.nodes_ptr, state_proof) %}

    let (hash_binary_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_binary_node);
    let (hash_edge_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_edge_node);

    let (keccak_ptr_seg: TruncatedKeccak*) = alloc();
    let hash_ptr = cast(keccak_ptr_seg, HashBuiltin*);
    
    let (root, value) = traverse{
        hash_binary_node_ptr=hash_binary_node_ptr, hash_edge_node_ptr=hash_edge_node_ptr, hash_ptr=hash_ptr,
        bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(
        cast(nodes_ptr, TrieNode**), proof_len, key_be
    );

    finalize_truncated_keccak{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(ptr_start=keccak_ptr_seg, ptr_end=cast(hash_ptr, TruncatedKeccak*));

    return (root=root, key=key_be, value=value);

}

func update_state_verification{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
}() -> (prev_root:felt, new_root:felt, key:felt, prev_value:felt, new_value:felt){
    alloc_locals;

    tempvar n_updates = 1;

    tempvar prev_root = nondet %{ state_proof.trie_root_prev %};
    tempvar new_root = nondet %{ state_proof.trie_root_post %};

    let (local update_dict: DictAccess*) = alloc();
    let update_dict_start = update_dict;

    tempvar key = nondet %{ state_proof.leaf_prev.key %};
    tempvar prev_value = nondet %{ state_proof.leaf_prev.data.value %};
    tempvar new_value = nondet %{ state_proof.leaf_post.data.value %};

    assert update_dict.key = key;
    assert update_dict.prev_value = prev_value;
    assert update_dict.new_value = new_value;

    let update_dict = update_dict + DictAccess.SIZE;

    let (consts) = patricia_update_constants_new();

    let (keccak_ptr_seg: TruncatedKeccak*) = alloc();
    local keccak_ptr_seg_start: TruncatedKeccak* = keccak_ptr_seg;

    %{
        preimage = {
            *generate_preimage(state_proof.state_proof_prev)
            *generate_preimage(state_proof.state_proof_post)
        }
    %}

    patricia_update_using_update_constants{hash_ptr=keccak_ptr_seg}(
        patricia_update_constants=consts,
        update_ptr=update_dict_start,
        n_updates=n_updates,
        height=251,
        prev_root=prev_root,
        new_root=new_root,
    );

    with keccak_ptr_seg{
        finalize_truncated_keccak{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
        }(ptr_start=keccak_ptr_seg_start, ptr_end=keccak_ptr_seg);
    }
    
    return (prev_root=prev_root, new_root=new_root, key=key, prev_value=prev_value, new_value=new_value);
}
