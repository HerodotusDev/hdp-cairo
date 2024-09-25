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

from src.memorizers.starknet import StarknetStorageSlotMemorizer
from src.types import ChainInfo

// func main{
//     pedersen_ptr: HashBuiltin*,
//     range_check_ptr,
//     bitwise_ptr: BitwiseBuiltin*,
//     poseidon_ptr: PoseidonBuiltin*,
// }() {
//     alloc_locals;
//     let pow2_array: felt* = pow2alloc251();

//     let storage_addresses: felt* = alloc();
//     local storage_count: felt;
//     local contract_address: felt;
//     %{ 
//         segments.write_arg(ids.storage_addresses, [int(key, 16) for key in program_input["storage_addresses"]])
//         ids.storage_count = len(program_input["storage_addresses"])
//         ids.contract_address = int(program_input["contract_address"], 16)
//     %}

//     with pow2_array {
//         let (values) = verify_proof(0x34e41ac48df28204189050de68200d53a035219260dec46824d009b225866d2, contract_address, storage_addresses, storage_count);
//     }

//     %{
//         i = 0
//         while i < ids.storage_count:
//             print("storage_addresses[", i, "]:", memory[ids.values + i])
//             i += 1
//     %}

//     return ();
// }

func verify_proofs{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_storage_slot_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}() {
    alloc_locals;
    local n_storage_items: felt;
    %{ ids.n_storage_items = len(batch["storages"]) %}

    verify_proofs_inner(n_storage_items, 0);

    return ();
}

func verify_proofs_inner{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    starknet_storage_slot_dict: DictAccess*,
    chain_info: ChainInfo,
    pow2_array: felt*,
}(n_storage_items: felt, index: felt) {
    alloc_locals;

    if (n_storage_items == index) {
        return ();
    }

    let storage_addresses: felt* = alloc();
    local state_commitment: felt;
    local storage_count: felt;
    local contract_address: felt;
    local block_number: felt;
    %{ 
        storage_proof = batch["storages"][ids.index]
        segments.write_arg(ids.storage_addresses, [int(key, 16) for key in storage_proof["storage_addresses"]])
        ids.storage_count = len(storage_proof["storage_addresses"])
        ids.contract_address = int(storage_proof["contract_address"], 16)
        ids.block_number = storage_proof["block_number"]
        # todo: get from header memorizer once ready
        ids.state_commitment = 0x34e41ac48df28204189050de68200d53a035219260dec46824d009b225866d2
    %}
    
    // Compute contract_root and write values to memorizer
    with contract_address, storage_addresses, block_number {
        let (contract_root) = validate_storage_proofs(0, storage_count, 0);
    }

    // Compute contract_state_hash
    local class_hash: felt;
    local nonce: felt;
    local contract_state_hash_version: felt;
    %{ 
        ids.class_hash = int(storage_proof["proof"]["contract_data"]["class_hash"], 16) 
        ids.nonce = int(storage_proof["proof"]["contract_data"]["nonce"], 16)
        ids.contract_state_hash_version = int(storage_proof["proof"]["contract_data"]["contract_state_hash_version"], 16)
    %}

    let (hash_value) = hash2{hash_ptr=pedersen_ptr}(class_hash, contract_root);
    let (hash_value) = hash2{hash_ptr=pedersen_ptr}(hash_value, nonce);
    let (contract_state_hash) = hash2{hash_ptr=pedersen_ptr}(hash_value, contract_state_hash_version);
    
    // Compute contract_state_hash
    %{ vm_enter_scope(dict(nodes=storage_proof["proof"]["contract_proof"])) %}
    let (contract_nodes, contract_nodes_len) = load_nodes();
    let (contract_tree_root, expected_contract_state_hash) = traverse(contract_nodes, contract_nodes_len, contract_address);
    %{ vm_exit_scope() %}

    // Assert Validity
    assert contract_state_hash = expected_contract_state_hash;

    local class_commitment: felt;
    %{ ids.class_commitment = int(storage_proof["proof"]["class_commitment"], 16) %}

    let (hash_chain: felt*) = alloc();
    assert hash_chain[0] = 28355430774503553497671514844211693180464; //STARKNET_STATE_V0
    assert hash_chain[1] = contract_tree_root;
    assert hash_chain[2] = class_commitment;
    
    let (state_root) = poseidon_hash_many(3, hash_chain);
    assert state_root = state_commitment;

    return ();
    
}

func validate_storage_proofs{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    starknet_storage_slot_dict: DictAccess*,
    chain_info: ChainInfo,
    contract_address: felt,
    storage_addresses: felt*,
    block_number: felt,
}(contract_root: felt, storage_count: felt, index: felt) -> (root: felt) {
    alloc_locals;
    if(index == storage_count) {
        return (root=contract_root);
    }

    // Compute contract_root
    %{ vm_enter_scope(dict(nodes=storage_proof["proof"]["contract_data"]["storage_proof"][ids.index])) %}
    let (contract_state_nodes, contract_state_nodes_len) = load_nodes();
    let (new_contract_root, value) = traverse(contract_state_nodes, contract_state_nodes_len, storage_addresses[index]);
    %{ vm_exit_scope() %}
    
    // Assert that the contract root is consistent between storage slots
    if(index != 0) {
        with_attr error_message("Contract Root Mismatch!") {
            assert contract_root = new_contract_root;
         }
    }

    StarknetStorageSlotMemorizer.add(
        chain_id=chain_info.id,
        block_number=block_number,
        contract_address=contract_address,
        storage_address=storage_addresses[index],
        value=value,
    );

    return validate_storage_proofs(new_contract_root, storage_count, index + 1);
}

func traverse{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
}(nodes: felt**, n_nodes: felt, expected_path: felt) -> (root: felt, value: felt) {
    alloc_locals;

    let leaf = nodes[n_nodes - 1];
    let (leaf_hash, path, path_length_pow2, value_idx) = init_leaf_nodes(expected_path, leaf, n_nodes);
    
    with nodes {
        let (root, traversed_path) = traverse_inner(n_nodes - 1, expected_path, leaf_hash, path, path_length_pow2);
    }

    %{ print("traversed_path:", hex(ids.traversed_path)) %}
    %{ print("expecteed_path:", hex(ids.expected_path)) %}
    %{ memory[ap] = nodes_types[ids.n_nodes - 1] %}
    jmp edge_node if [ap] != 0, ap++;
    assert traversed_path = expected_path;
    return (root=root, value=leaf[value_idx]);

    edge_node:
    let proof_mode = derive_proof_mode(leaf[1], leaf[2], expected_path);
    %{ print("proof_mode:", ids.proof_mode) %}
    if (proof_mode == 1) {
        assert traversed_path = expected_path;
        return (root=root, value=leaf[value_idx]);
    } else {
        assert_subpath(traversed_path, expected_path, leaf[2]);
        return (root=root, value=0);
    }
}

func traverse_inner{
    pedersen_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    nodes: felt**,
}(n_nodes: felt, expected_path: felt, hash_value: felt, traversed_path: felt, path_length_pow2: felt) -> (root: felt, traversed_path: felt) {
    alloc_locals;
    if(n_nodes == 0) {
        return (root=hash_value, traversed_path=traversed_path);
    }

    let node = nodes[n_nodes - 1];
    %{ memory[ap] = nodes_types[ids.n_nodes - 1] %}
    jmp edge_node if [ap] != 0, ap++;

    // binary_node:
    let (result) = bitwise_and(expected_path, path_length_pow2);
    local new_path: felt;
    if(result == 0) {
        assert hash_value = node[0];
        new_path = traversed_path;
    } else {
        assert hash_value = node[1];
        new_path = traversed_path + path_length_pow2;
    }
    let next_path_length_pow2 = path_length_pow2 * 2;
    let next_hash = hash_binary_node(node);
    
    return traverse_inner(n_nodes - 1, expected_path, next_hash, new_path, next_path_length_pow2);

    edge_node:
    assert hash_value = node[0];
    let next_path = traversed_path + node[1] * path_length_pow2;
    let next_path_length_pow2 = path_length_pow2 * pow2_array[node[2]];
    let next_hash = hash_edge_node(node);

    return traverse_inner(n_nodes - 1, expected_path, next_hash, next_path, next_path_length_pow2);
}

func hash_binary_node{
    pedersen_ptr: HashBuiltin*,
}(node: felt*) -> felt {
    let (node_hash) = hash2{hash_ptr=pedersen_ptr}(node[0], node[1]);
    return node_hash;
}

func hash_edge_node{
    pedersen_ptr: HashBuiltin*,
}(node: felt*) -> felt {
    let (node_hash) = hash2{hash_ptr=pedersen_ptr}(node[0], node[1]);
    return node_hash + node[2];
}

func init_leaf_nodes{
    pedersen_ptr: HashBuiltin*,
    pow2_array: felt*,
    bitwise_ptr: BitwiseBuiltin*,
}(expected_path: felt, leaf: felt*, n_nodes: felt) -> (leaf_hash: felt, path: felt, path_length_pow2: felt, value_idx: felt) {

    %{ memory[ap] = nodes_types[ids.n_nodes - 1] %}
    jmp edge_node if [ap] != 0, ap++;
    let leaf_hash = hash_binary_node(leaf);
    let (value_idx) = bitwise_and(expected_path, 1);

    return (leaf_hash=leaf_hash, path=value_idx, path_length_pow2=2, value_idx=value_idx);

    edge_node:
    let leaf_hash = hash_edge_node(leaf);
    let path = leaf[1];
    let path_length_pow2 = pow2_array[leaf[2]];
    return (leaf_hash=leaf_hash, path=path, path_length_pow2=path_length_pow2, value_idx=0);
}

// TODO: Make sound!!!!
func derive_proof_mode{
    // bitwise_ptr: BitwiseBuiltin*,
    // pow2_array: felt*,
}(leaf_path: felt, path_len: felt, expected_path: felt) -> felt {
    alloc_locals;

    local r: felt;
    %{
        q, ids.r = divmod(ids.expected_path, 2**ids.path_len)
    %}

    if (r != leaf_path) {
        return 0; // Non-Inclusion Proof
    } else {
        return 1; // Inclusion Proof
    }
}

// TODO: Make sound!!!!
func assert_subpath(path: felt, expected_path: felt, edge_path_len: felt) {
    alloc_locals;
    local q_path: felt;
    local q_expected_path: felt;
    %{
        ids.q_expected_path, r = divmod(ids.expected_path, 2**(ids.edge_path_len))
        ids.q_path, r = divmod(ids.path, 2**(ids.edge_path_len))
        print("q_path:", ids.q_path)
        print("q_expected_path:", ids.q_expected_path)
    %}

    with_attr error_message("Non-inclusion subpath Mismatch!") {
        assert q_path = q_expected_path;
    }

    return ();
}

func load_nodes() -> (nodes: felt**, len: felt) {
    alloc_locals;
    let (nodes: felt**) = alloc();
    local len: felt;
   %{ 
        nodes_types = []
        ids.len = len(nodes)
        for i in range(len(nodes)):
            nodes_types.append(len(nodes[i]) % 2) # 0 for binary, 1 for edge
            for j in range(len(nodes[i])):
                nodes[i][j] = int(nodes[i][j],16)
        segments.write_arg(ids.nodes, nodes)
    %}
    return (nodes=nodes, len=len);
}

