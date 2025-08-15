// %builtins pedersen range_check bitwise poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.sponge_as_hash import SpongeHashBuiltin
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import HashBuiltin, PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_new, dict_update, dict_squash
from starkware.cairo.common.builtin_poseidon.poseidon import (
    poseidon_hash_single,
    poseidon_hash,
    poseidon_hash_many,
)

from packages.eth_essentials.lib.utils import bitwise_divmod
from src.memorizers.starknet.memorizer import StarknetMemorizer, StarknetHashParams
from src.decoders.starknet.header_decoder import StarknetHeaderDecoder, StarknetHeaderFields
from src.types import ChainInfo, TrieNode, TrieNodeBinary, TrieNodeEdge
from src.verifiers.mpt import HashNodeBuiltin, traverse

const STARKNET_STATE_V0 = 28355430774503553497671514844211693180464;

func verify_proofs{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;

    tempvar n_storage_items: felt = nondet %{ len(batch_starknet.storages) %};
    
    let (hash_binary_node_ptr) = get_label_location(HashNodeBuiltin.hash_binary_node);
    let (hash_edge_node_ptr) = get_label_location(HashNodeBuiltin.hash_edge_node);
    with hash_binary_node_ptr, hash_edge_node_ptr {
        verify_proofs_loop(n_storage_items, 0);
    }

    return ();
}

// ToDo: this should be refactored, as we use to many call stack headers. We need an entrypoint for testing though
func verify_proofs_loop{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
    hash_binary_node_ptr: felt*,
    hash_edge_node_ptr: felt*,
}(n_storage_items: felt, idx: felt) {
    alloc_locals;

    if (n_storage_items == idx) {
        return ();
    }

    %{ storage_starknet = batch_starknet.storages[ids.idx] %}

    tempvar block_number: felt = nondet %{ storage_starknet.block_number %};

    let memorizer_key = StarknetHashParams.header(
        chain_id=chain_info.id, block_number=block_number
    );
    let (header_data) = StarknetMemorizer.get(key=memorizer_key);
    let (state_root) = StarknetHeaderDecoder.get_field(
        header_data, StarknetHeaderFields.STATE_ROOT
    );

    verify_proofs_inner(state_root, block_number, idx);

    return verify_proofs_loop(n_storage_items, idx + 1);
}

func verify_proofs_inner{
    range_check_ptr,
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
    hash_binary_node_ptr: felt*,
    hash_edge_node_ptr: felt*,
}(state_root: felt, block_number: felt, index: felt) {
    alloc_locals;

    tempvar storage_count: felt = nondet %{ len(storage_starknet.storage_addresses) %};
    tempvar contract_address: felt = nondet %{ storage_starknet.contract_address %};

    let (storage_addresses: felt*) = alloc();
    %{ segments.write_arg(ids.storage_addresses, [int(x, 16) for x in storage_starknet.storage_addresses]) %}

    // Compute contract_root and write values to memorizer
    with contract_address, storage_addresses, block_number {
        let (contract_root) = validate_storage_proofs(0, storage_count, 0);
    }

    // Compute contract_state_hash
    tempvar class_hash: felt = nondet %{ storage_starknet.proof.contract_data.class_hash %};
    tempvar nonce: felt = nondet %{ storage_starknet.proof.contract_data.nonce %};
    tempvar contract_state_hash_version: felt = nondet %{ storage_starknet.proof.contract_data.contract_state_hash_version %};

    let (hash_value) = hash2{hash_ptr=pedersen_ptr}(class_hash, contract_root);
    let (hash_value) = hash2{hash_ptr=pedersen_ptr}(hash_value, nonce);
    let (contract_state_hash) = hash2{hash_ptr=pedersen_ptr}(
        hash_value, contract_state_hash_version
    );

    // Compute contract_state_hash
    tempvar contract_nodes_len: felt = nondet %{ len(storage_starknet.proof.contract_proof) %};
    let (contract_nodes: felt**) = alloc();
    %{ segments.write_arg(ids.contract_nodes, storage_starknet.proof.contract_proof) %}

    let (contract_tree_root, expected_contract_state_hash) = traverse{
        hash_binary_node_ptr=hash_binary_node_ptr, hash_edge_node_ptr=hash_edge_node_ptr, hash_ptr=pedersen_ptr,
        bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(
        cast(contract_nodes, TrieNode**), contract_nodes_len, contract_address
    );

    // Assert Validity
    assert contract_state_hash = expected_contract_state_hash;

    let (hash_chain: felt*) = alloc();
    assert hash_chain[0] = STARKNET_STATE_V0;
    assert hash_chain[1] = contract_tree_root;
    assert hash_chain[2] = nondet %{ storage_starknet.proof.class_commitment %};

    let (computed_state_root) = poseidon_hash_many(3, hash_chain);
    assert state_root = computed_state_root;

    return ();
}

// This function iteratively validates contract storage proofs. It is ensures that each proof computes the same contract root.
// The values of the storage slots are added to the memorizer.
// The contract root is returned and used to compute the contract state hash.
func validate_storage_proofs{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    starknet_memorizer: DictAccess*,
    chain_info: ChainInfo,
    contract_address: felt,
    storage_addresses: felt*,
    block_number: felt,
    hash_binary_node_ptr: felt*,
    hash_edge_node_ptr: felt*,
}(contract_root: felt, storage_count: felt, idx: felt) -> (root: felt) {
    alloc_locals;

    if (storage_count == idx) {
        return (root=contract_root);
    }

    // Compute contract_root
    tempvar contract_state_nodes_len: felt = nondet %{ len(storage_starknet.proof.contract_data.storage_proofs[ids.idx]) %};
    let (contract_state_nodes: felt**) = alloc();
    %{ segments.write_arg(ids.contract_state_nodes, storage_starknet.proof.contract_data.storage_proofs[ids.idx]) %}

    let (new_contract_root, value) = traverse{
        hash_binary_node_ptr=hash_binary_node_ptr, hash_edge_node_ptr=hash_edge_node_ptr, hash_ptr=pedersen_ptr,
        bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(
        cast(contract_state_nodes, TrieNode**), contract_state_nodes_len, storage_addresses[idx]
    );

    // Assert that the contract root is consistent between storage slots
    if (idx != 0) {
        with_attr error_message("Contract Root Mismatch!") {
            assert contract_root = new_contract_root;
        }
    }

    let memorizer_key = StarknetHashParams.storage(
        chain_id=chain_info.id,
        block_number=block_number,
        contract_address=contract_address,
        storage_address=storage_addresses[idx],
    );

    let (data) = alloc();
    assert [data] = value;
    StarknetMemorizer.add(key=memorizer_key, data=data);

    return validate_storage_proofs(new_contract_root, storage_count, idx + 1);
}
