from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_uint256s
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.utils import compute_results_entry
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

// TODO: it is single task for now
func compute_tasks_hash{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    encoded_task: felt*, task_bytes_len: felt
) -> Uint256 {
    alloc_locals;

    let (task_hash: Uint256) = keccak(encoded_task, task_bytes_len);
    let (task_hash) = uint256_reverse_endian(task_hash);
    %{
        target_task_hash = hex(ids.task_hash.low + ids.task_hash.high*2**128)[2:]
        print(f"Task Hash: 0x{target_task_hash}")
    %}

    return task_hash;
}

func compute_tasks_root{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    task_hash: Uint256
) -> Uint256 {
    let (leafs: Uint256*) = alloc();
    assert leafs[0] = task_hash;

    return compute_merkle_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(leafs=leafs, leafs_len=1);
}

func compute_results_root{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}(task_hash: Uint256, result: Uint256) -> Uint256 {
    alloc_locals;
    let (local leafs: Uint256*) = alloc();

    let entry_hash = compute_results_entry(task_hash, result);
    assert leafs[0] = entry_hash;

    return compute_merkle_root{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr
    }(leafs=leafs, leafs_len=1);
}

func compute_merkle_root{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    leafs: Uint256*, leafs_len: felt
) -> Uint256 {
    if (leafs_len == 0) {
        // keccak(0)
        return (
            Uint256(low=0x6612f7b477d66591ff96a9e064bcc98a, high=0xbc36789e7a1e281436464229828f817d)
        );
    }

    let (tree: Uint256*) = alloc();
    let tree_len = 2 * leafs_len - 1;

    // writes to tree
    compute_leaf_hashes{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr, tree=tree
    }(leafs=leafs, leafs_len=leafs_len, tree_len=tree_len, index=0);

    compute_merkle_root_inner{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr, tree=tree
    }(tree_range=tree_len - leafs_len - 1, index=0);

    // reverse endianess to use in solidity
    let (root) = uint256_reverse_endian{bitwise_ptr=bitwise_ptr}(num=tree[0]);

    return (root);
}

// Implements the merkle tree building logic. This follows the unordered StandardMerkleTree implementation of OpenZeppelin
func compute_merkle_root_inner{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, tree: Uint256*
}(tree_range: felt, index: felt) {
    if (tree_range + 1 == index) {
        return ();
    }

    let left_idx = (tree_range - index) * 2 + 1;
    let right_idx = (tree_range - index) * 2 + 2;

    let node = hash_pair(left=tree[left_idx], right=tree[right_idx]);
    assert tree[tree_range - index] = node;

    return compute_merkle_root_inner(tree_range=tree_range, index=index + 1);
}

// Double hashes the results
// ToDo: would be nice to have a generic double hash function
func compute_leaf_hashes{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, tree: Uint256*
}(leafs: Uint256*, leafs_len: felt, tree_len: felt, index: felt) {
    if (index == leafs_len) {
        return ();
    }

    let leaf_hash = compute_leaf_hash_inner(leafs[index]);
    assert tree[tree_len - 1 - index] = leaf_hash;

    return compute_leaf_hashes(
        leafs=leafs, leafs_len=leafs_len, tree_len=tree_len, index=index + 1
    );
}

// Double keccak hashes the leaf to create the leaf hash
func compute_leaf_hash_inner{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}(leaf: Uint256) -> Uint256 {
    alloc_locals;
    let (first_round_input) = alloc();
    let first_round_input_start = first_round_input;

    // convert to felts
    keccak_add_uint256{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, inputs=first_round_input
    }(num=leaf, bigend=0);

    // hash first round
    let (first_hash) = keccak(first_round_input_start, 32);

    let (second_round_input) = alloc();
    let second_round_input_start = second_round_input;
    keccak_add_uint256{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, inputs=second_round_input
    }(num=first_hash, bigend=0);

    let (leaf_hash) = keccak(second_round_input_start, 32);
    return (leaf_hash);
}

// Hashes a pair value in the merkle tree.
// The pair is ordered by the value of the left and right elements.
func hash_pair{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    left: Uint256, right: Uint256
) -> Uint256 {
    alloc_locals;
    let (pair: Uint256*) = alloc();
    local is_left_smaller: felt;

    // ToDo: We have to figure out if the pair-wise order is something we want to do in a hint. The order could be messed with by a malicious prover.
    %{
        def flip_endianess(val):
            val_hex = hex(val)[2:]

            if len(val_hex) % 2:
                val_hex = '0' + val_hex

            # Convert hex string to bytes
            byte_data = bytes.fromhex(val_hex)
            num = int.from_bytes(byte_data, byteorder="little")

            return num

        # In LE Uint256, the low and high are reversed
        left = flip_endianess(ids.left.low) * 2**128 + flip_endianess(ids.left.high)
        right = flip_endianess(ids.right.low) * 2**128 + flip_endianess(ids.right.high)

        # Compare the values to derive correct hashing order
        if left < right:
            ids.is_left_smaller = 1
            #print(f"H({hex(left)}, {hex(right)})")
        else:
            #print(f"H({hex(right)}, {hex(left)})")
            ids.is_left_smaller = 0
    %}

    if (is_left_smaller == 1) {
        assert pair[0] = left;
        assert pair[1] = right;
    } else {
        assert pair[0] = right;
        assert pair[1] = left;
    }

    let (res) = keccak_uint256s{range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr}(
        n_elements=2, elements=pair
    );

    return (res);
}
