from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.sponge_as_hash import SpongeHashBuiltin
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.invoke import invoke
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

// Function used to traverse the passed nodes. The nodes are hashed from the leaf to the root.
// This function can be used for inclusion or non-inclusion proofs. In case of non-inclusion,
// the function will return the root and a zero value.
func traverse{
    hash_binary_node_ptr: felt*, hash_edge_node_ptr: felt*, hash_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(nodes: TrieNode**, n_nodes: felt, expected_path: felt) -> (root: felt, value: felt) {
    alloc_locals;

    local node: TrieNode* = nodes[n_nodes - 1];
    %{ memory[ap] = CairoTrieNode(ids.node).is_edge() %}
    jmp edge_leaf if [ap] != 0, ap++;
    return traverse_binary_leaf(nodes, n_nodes, expected_path);

    edge_leaf:
    return traverse_edge_leaf(nodes, n_nodes, expected_path);
}

// Traverse a proof, where the last proof node is an edge node.
// This could be an inclusion or non-inclusion proof.
func traverse_edge_leaf{
    hash_binary_node_ptr: felt*, hash_edge_node_ptr: felt*, hash_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(nodes: TrieNode**, n_nodes: felt, expected_path: felt) -> (root: felt, value: felt) {
    alloc_locals;

    let leaf: TrieNodeEdge* = cast(nodes[n_nodes - 1], TrieNodeEdge*);
    let leaf_hash = hash_node{func_ptr=hash_edge_node_ptr, hash_ptr=hash_ptr}(cast(leaf, felt*));
    let node_path = leaf.value;

    // First we precompute the eval depth of the proof via hint.
    // In case of non-inclusion, we dont nececcary need to traverse the entire depth of the tree.
    // The eval depth is how many bits we went down the binary tree from the root for the proof.
    tempvar eval_depth: felt = nondet %{ [ if CairoTrieNode(ids.nodes[i]).is_edge() CairoTrieNode(ids.nodes[i]).path_len else 1 for i in ids.n_nodes ].sum() %};

    // If the eval_depth is not 251, we no we are dealing with a non-inclusion proof. (we can also have non-inclusion proofs with eval depth 251 though)
    // To verify these proofs correctly, we need to shift the traversed path, so it matches the length of the expected path (251 bits).
    // The eval depth, is the depth of the proof we need to evaluate.

    // We want to end up with something like this:
    // Last edge node: {value: 1337, path: 0x8835, path_len: 16}
    // Expected path:  0x71303bca4a8f9507624f6cc042ec4cfb9b16a629ac39b533c92f64ff82d3a4a (always 251 bits long)
    // Traversed path: 0x71303bca4a8f8835 (63 bits)
    // Shifted path:   0x71303bca4a8f883500000000000000000000000000000000000000000000000 (251 bits)
    //                               ^   ^
    //                               |   |
    //                          _____|   |_____
    //                         |               |
    //             eval_depth - leaf_len       eval_depth
    local edge_node_shift = 251 - (eval_depth - leaf.len);

    // Since divisions are impractical in Cairo, we traverse the proof from the bottom up.
    // To track where we are in the tree, we use this variable: path_length_pow2
    // We initializer it with the shifted index we computed above (pow of 2)
    // This results in us skipping all of the proof nodes that come before the edge node.
    let edge_node_start_position = pow2_array[edge_node_shift];

    with nodes {
        let (root, traversed_path, traversed_eval_depth) = traverse_inner(
            n_nodes - 1, expected_path, leaf_hash, node_path, edge_node_start_position, leaf.len
        );
    }

    // As we precomputed the eval depth, we need to validate the hint here.
    assert traversed_eval_depth = eval_depth;

    let (proof_mode) = derive_proof_mode(leaf.value, edge_node_start_position, expected_path);
    if (proof_mode == 1) {
        assert traversed_path = expected_path;
        return (root=root, value=leaf.child);
    } else {
        // If we have a valid non-inclusion proof, we return 0 as value.
        assert_subpath(traversed_path, expected_path, edge_node_start_position);
        return (root=root, value=0);
    }
}

// Traverse a proof, where the last proof node is a binary node.
// This is always an inclusion proof.
func traverse_binary_leaf{
    hash_binary_node_ptr: felt*, hash_edge_node_ptr: felt*, hash_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*
}(nodes: TrieNode**, n_nodes: felt, expected_path: felt) -> (root: felt, value: felt) {
    alloc_locals;

    let leaf: TrieNodeBinary* = cast(nodes[n_nodes - 1], TrieNodeBinary*);
    let leaf_hash = hash_node{func_ptr=hash_binary_node_ptr, hash_ptr=hash_ptr}(cast(leaf, felt*));

    // In this case, the initial path is the least significant bit of the expected path.
    // This value is also used for retrieving the value from the leaf.
    let (node_path) = bitwise_and(expected_path, 1);
    let path_length_pow2 = 2;

    with nodes {
        let (root, traversed_path, _) = traverse_inner(
            n_nodes - 1, expected_path, leaf_hash, node_path, path_length_pow2, 0
        );
    }

    // If the leaf node is a binary node, we always have inclusion.
    assert traversed_path = expected_path;

    if (node_path == 0) {
        return (root=root, value=leaf.left);
    }

    if (node_path == 1) {
        return (root=root, value=leaf.right);
    }

    assert 0 = 1;

    return (root=0, value=0);
}

// Inner traverse function used to traverse the nodes.
// This function will return the path is took through the tree, along with the computed root.
func traverse_inner{
    hash_binary_node_ptr: felt*, hash_edge_node_ptr: felt*, hash_ptr: HashBuiltin*,
    bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, nodes: TrieNode**
}(
    n_nodes: felt,
    expected_path: felt,
    hash_value: felt,
    traversed_path: felt,
    path_length_pow2: felt,
    traversed_eval_depth: felt,
) -> (root: felt, traversed_path: felt, traversed_eval_depth: felt) {
    alloc_locals;

    if (n_nodes == 0) {
        return (
            root=hash_value,
            traversed_path=traversed_path,
            traversed_eval_depth=traversed_eval_depth,
        );
    }

    local node: TrieNode* = nodes[n_nodes - 1];
    %{ memory[ap] = CairoTrieNode(ids.node).is_edge() %}
    jmp edge_node if [ap] != 0, ap++;

    // binary_node:
    let node_binary = cast(node, TrieNodeBinary*);
    let (result) = bitwise_and(expected_path, path_length_pow2);
    local new_path: felt;
    if (result == 0) {
        assert hash_value = node_binary.left;
        new_path = traversed_path;
    } else {
        assert hash_value = node_binary.right;
        new_path = traversed_path + path_length_pow2;
    }
    let next_path_length_pow2 = path_length_pow2 * 2;
    let next_hash = hash_node{func_ptr=hash_binary_node_ptr, hash_ptr=hash_ptr}(cast(node_binary, felt*));

    return traverse_inner(
        n_nodes - 1,
        expected_path,
        next_hash,
        new_path,
        next_path_length_pow2,
        traversed_eval_depth + 1,
    );

    edge_node:
    let node_edge = cast(node, TrieNodeEdge*);
    assert hash_value = node_edge.child;
    let next_path = traversed_path + node_edge.value * path_length_pow2;
    let next_path_length_pow2 = path_length_pow2 * pow2_array[node_edge.len];
    let next_hash = hash_node{func_ptr=hash_edge_node_ptr, hash_ptr=hash_ptr}(cast(node_edge, felt*));

    return traverse_inner(
        n_nodes - 1,
        expected_path,
        next_hash,
        next_path,
        next_path_length_pow2,
        traversed_eval_depth + node_edge.len,
    );
}

// If the leaf node is an edge node, there are two cases:
// 1. the last bytes of the expected_path match the leaf edge path -> Inclusion
// 2. the last bytes of the expected_path do not match the leaf edge path -> Non-Inclusion
// This function checks this by using divmod and comparing the remainder with the leaf edge path.
func derive_proof_mode{bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    leaf_path: felt, edge_node_start_position: felt, expected_path: felt
) -> (proof_mode: felt) {
    // Compute q and r from the expected path and the path length of the edge node.
    let (_q, r) = bitwise_divmod(expected_path, edge_node_start_position);

    if (r != leaf_path) {
        return (proof_mode=0);  // Non-Inclusion Proof
    } else {
        return (proof_mode=1);  // Inclusion Proof
    }
}

// This function checks if a potential non-inclusion proof is valid.
// In the previous steps of the verification, we have recreated the trie root of a contracts storage.
// In case of a non-inclusion proof, we have proven the inclusion of the closest edge node to the expected path
// To prove the non-inclusion path, is not part of the tree, we have to show, that the path up until the edge node, is part of the expected path.
// E.g.
// Last edge: {value: 1337, path: 0x8835, path_len: 16}
// Expected path (EP):  0x71303bca4a8f9507624f6cc042ec4cfb9b16a629ac39b533c92f64ff82d3a4a (always 251 bits long)
// Traversed path:      0x71303bca4a8f8835 (63 bits)
// Shifted path (SP):   0x71303bca4a8f883500000000000000000000000000000000000000000000000 (251 bits)
// We need to show, that:
// e_q, e_r = divmod(EP, edge_node_start_position) | e_q = 0x71303bca4a8f, e_r = 0x9507624f6cc042ec4cfb9b16a629ac39b533c92f64ff82d3a4a
// s_q, s_r = divmod(SP, edge_node_start_position) | s_q = 0x71303bca4a8f, s_r = 0x883500000000000000000000000000000000000000000000000
// assert s_q == e_q
// The shows, that until the edge node path (0x8835) the traversed path is part of the expected path.
// Since no further branching is possible once we have reached and edge node, we are now sure that the expected path is not part of the tree.
// Note: Proving s_r != e_r is also required. We have done this in derive_proof_mode already.
func assert_subpath{bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    shifted_path: felt, expected_path: felt, edge_node_start_position: felt
) {
    alloc_locals;

    // Compute start of edge node for divmod
    let (shifted_traversed_path, _r) = bitwise_divmod(shifted_path, edge_node_start_position);
    let (expected_path, _r) = bitwise_divmod(expected_path, edge_node_start_position);

    with_attr error_message("Non-inclusion subpath Mismatch!") {
        assert shifted_traversed_path = expected_path;
    }

    return ();
}

// Hash function for nodes. (abstract version)
func hash_node{func_ptr: felt*, hash_ptr: HashBuiltin*}(node: felt*) -> felt {
    tempvar invoke_params = cast(
        new (
            hash_ptr, node,
        ),
        felt*,
    );
    invoke(func_ptr, 2, invoke_params);

    let node_hash = [ap - 1];
    let hash_ptr = cast([ap - 2], HashBuiltin*);

    return node_hash;
}

namespace HashNodeBuiltin {
    // Hash function for binary nodes. (pedersen version)
    func hash_binary_node{hash_ptr: HashBuiltin*}(node: TrieNodeBinary*) -> felt {
        let (node_hash) = hash2{hash_ptr=hash_ptr}(node.left, node.right);
        return node_hash;
    }

    // Hash function for edge nodes. (pedersen version)
    func hash_edge_node{hash_ptr: HashBuiltin*}(node: TrieNodeEdge*) -> felt {
        let (node_hash) = hash2{hash_ptr=hash_ptr}(node.child, node.value);
        return node_hash + node.len;
    }
}

namespace HashNodeTruncatedKeccak {
    // Hash function for binary nodes. (truncated_keccak version)
    func hash_binary_node{hash_ptr: HashBuiltin*}(node: TrieNodeBinary*) -> felt {
        hash_ptr.result = nondet %{ keccak160(ids.node.left, ids.node.right) %};
        let (node_hash) = hash2{hash_ptr=hash_ptr}(node.left, node.right);
        return node_hash;
    }

    // Hash function for edge nodes. (truncated_keccak version)
    func hash_edge_node{hash_ptr: HashBuiltin*}(node: TrieNodeEdge*) -> felt {
        hash_ptr.result = nondet %{ keccak160(ids.node.child, ids.node.value) %};
        let (node_hash) = hash2{hash_ptr=hash_ptr}(node.child, node.value);
        return node_hash + node.len;
    }
}
