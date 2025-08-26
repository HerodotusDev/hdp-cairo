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

func inclusion_state_verification{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    pow2_array: felt*,
    injected_state_memorizer: DictAccess*,
}() -> (root: felt, value: felt){
    alloc_locals;
    
    local root_hash: felt;
    %{ ids.root_hash = state_proof_read.trie_root %}

    local key_be: felt; 
    %{ ids.key_be = state_proof_read.leaf.key %} 

    tempvar proof_len: felt = nondet %{ len(state_proof) %};

    let (nodes_ptr: felt**) = alloc();
    %{ segments.write_arg(ids.nodes_ptr, state_proof) %}

    let (hash_binary_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_binary_node);
    let (hash_edge_node_ptr) = get_label_location(HashNodeTruncatedKeccak.hash_edge_node);

    let (keccak_ptr_seg: TruncatedKeccak*) = alloc();
    let hash_ptr = cast(keccak_ptr_seg, HashBuiltin*);
    local keccak_ptr_seg_start: TruncatedKeccak* = keccak_ptr_seg;
    
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

    let memorizer_key = InjectedStateHashParams.read{poseidon_ptr=poseidon_ptr}(root_hash=root_hash, key_be=key_be);
    InjectedStateMemorizer.add(key=memorizer_key, data=cast(key_be, felt*));

    return (root=root, value=value);

}

func update_state_verification(
    injected_state_memorizer: DictAccess*,
) -> (value: felt*, value_len: felt){
    alloc_locals;

    //todo()!
    assert 1 = 0;
    let (res: felt*) = alloc();
    return (value=res, value_len=0);
}