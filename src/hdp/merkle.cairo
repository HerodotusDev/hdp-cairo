from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_uint256s
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.hdp.types import BlockSampledComputationalTask
from src.hdp.utils import compute_results_entry
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

// Creates the leaf hash for a given value. This can be a task or a result entry.
// Leafs are double hashed, so h(h(value)) is returned.
// ToDo: Need to get rid of this back and forth Uint256 conversions. Super ugly.
func compute_leaf_hash{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(value: Uint256) -> Uint256 {
    alloc_locals;
    let (first_round_input) = alloc();
    let first_round_input_start = first_round_input;

    // convert to felts
    keccak_add_uint256{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        inputs=first_round_input
    }(
        num=value,
        bigend=0
    );

    // hash first round
    let (first_hash) = keccak(first_round_input_start, 32);

    let (second_round_input) = alloc();
    let second_round_input_start = second_round_input;
    keccak_add_uint256{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        inputs=second_round_input
    }(
        num=first_hash,
        bigend=0
    );

    let (result) = keccak(second_round_input_start, 32);
    return result;
}

// Computes the results merkle root
// Inputs:
//  - tasks: The tasks that were sampled
//  - results: The results of the tasks
//  - tasks_len: The number of tasks & results. These are the same length always
// Outputs:
//  - The merkle root of the results
func compute_results_root{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(tasks: BlockSampledComputationalTask*, results: Uint256*, tasks_len: felt) -> Uint256 {
    let (tree: Uint256*) = alloc();
    let tree_len = 2 * tasks_len - 1;

    // create leaf hashes and populate the tree
    double_hash_results{
        range_check_ptr=range_check_ptr,
        tree=tree,
        results=results,
        tasks=tasks
    }(
        n_tasks=tasks_len,
        tree_len=tree_len,
        index=0
    );

    // builds merkle tree
    compute_merkle_root_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        tree=tree
    }(
        tree_range=tree_len - tasks_len - 1,
        index=0
    );

    // reverse endianess to compare in solidity
    let (root) = uint256_reverse_endian{
        bitwise_ptr=bitwise_ptr,
    }(
        num=tree[0]
    );

    return (root);

}

// Computes the tasks merkle root
// Inputs:
//  - tasks: The tasks that were sampled
//  - tasks_len: The number of tasks
// Outputs:
//  - The merkle root of the tasks
func compute_tasks_root{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(tasks: BlockSampledComputationalTask*, tasks_len: felt) -> Uint256 {
    let (tree: Uint256*) = alloc();
    let tree_len = 2 * tasks_len - 1;

    // create leaf hashes and populate the tree
    double_hash_tasks{
        range_check_ptr=range_check_ptr,
        tree=tree,
        tasks=tasks
    }(
        n_tasks=tasks_len,
        tree_len=tree_len,
        index=0
    );

    compute_merkle_root_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        tree=tree
    }(
        tree_range=tree_len - tasks_len - 1,
        index=0
    );

    // reverse endianess to use in solidity
    let (root) = uint256_reverse_endian{
        bitwise_ptr=bitwise_ptr,
    }(
        num=tree[0]
    );

    return (root);
}

// Implements the merkle tree building logic. This follows the unordered StandardMerkleTree implementation of OpenZeppelin
func compute_merkle_root_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    tree: Uint256*,
}(tree_range: felt, index: felt) {
    if(tree_range + 1 == index) {
        return ();
    }

    let left_idx = (tree_range - index) * 2 + 1;
    let right_idx = (tree_range - index) * 2 + 2;
    
    let node = hash_pair(
        left=tree[left_idx],
        right=tree[right_idx]
    );
    assert tree[tree_range - index] = node;

    return compute_merkle_root_inner(
        tree_range=tree_range,
        index=index+1
    );
    
}

// Double hashes the tasks
func double_hash_tasks{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    tree: Uint256*,
    tasks: BlockSampledComputationalTask*,
}(n_tasks: felt, tree_len: felt, index: felt) {
    if(index == n_tasks) {
        return ();
    }

    let leaf_hash = compute_leaf_hash(tasks[index].hash);

    assert tree[tree_len - 1 - index] = leaf_hash;

    return double_hash_tasks(
        n_tasks=n_tasks,
        tree_len=tree_len,
        index=index+1
    );
}

// Double hashes the results
func double_hash_results{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    tree: Uint256*,
    results: Uint256*,
    tasks: BlockSampledComputationalTask*,
}(n_tasks: felt, tree_len: felt, index: felt) {
    if(index == n_tasks) {
        return ();
    }

    let entry_hash = compute_results_entry(tasks[index].hash, results[index]);
    let leaf_hash = compute_leaf_hash(entry_hash);

    assert tree[tree_len - 1 - index] = leaf_hash;

    return double_hash_results(
        n_tasks=n_tasks,
        tree_len=tree_len,
        index=index+1
    );
}

// Hashes a pair value in the merkle tree.
// The pair is ordered by the value of the left and right elements.
func hash_pair{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(left: Uint256, right: Uint256) -> Uint256 {
    alloc_locals;
    let (pair: Uint256*) = alloc();
    local is_left_smaller: felt;
    
    // ToDo: I think we can get away with handling this in a hint. Or could this be exploited somehow?
    %{

        def flip_endianess(val):
            val = hex(val)[2:]
            # Convert hex string to bytes
            byte_data = bytes.fromhex(val)
            num = int.from_bytes(byte_data, byteorder="little")

            return num

        # In LE Uint256, the low and high are reversed
        left = flip_endianess(ids.left.low) * 2**128 + flip_endianess(ids.left.high)
        right = flip_endianess(ids.right.low) * 2**128 + flip_endianess(ids.right.high)

        # Compare the values to derive correct hashing order
        if left < right:
            ids.is_left_smaller = 1
            print(f"H({hex(left)}, {hex(right)})")
        else:
            print(f"H({hex(right)}, {hex(left)})")
            ids.is_left_smaller = 0
    %}

    if(is_left_smaller == 1) {
        assert pair[0] = left;
        assert pair[1] = right;
    } else {
        assert pair[0] = right;
        assert pair[1] = left;
    }

    let (res) = keccak_uint256s{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
    }(
        n_elements=2, 
        elements=pair
    );

    // %{
    //     hash_val = flip(ids.res.low) * 2**128 + flip(ids.res.high)
    //     print(f"Node hash: {hex(hash_val)}")
    // %}

    return (res);
}