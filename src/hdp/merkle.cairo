%builtins range_check bitwise keccak

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend, keccak_uint256s
from starkware.cairo.common.keccak_utils.keccak_utils import keccak_add_uint256
from src.hdp.types import BlockSampledComputationalTask
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.uint256 import Uint256

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
        bigend=1
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

func compute_merkle_root{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(leafs: Uint256*, leafs_len: felt, index: felt){
    let (tree: Uint256*) = alloc();
    let tree_len = 2 * leafs_len - 1;

    %{
        print("leafs_len: ", ids.leafs_len)
        print("tree_len: ", ids.tree_len)
    %}

    double_hash_leafs{
        range_check_ptr=range_check_ptr,
        tree=tree,
        leafs=leafs
    }(
        n_leafs=leafs_len,
        tree_len=tree_len,
        index=0
    );

    compute_merkle_root_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        tree=tree
    }(
        tree_range=tree_len - leafs_len - 1,
        index=0
    );

    %{
        print("tree[0]: ", hex(ids.tree[0].low), hex(ids.tree[0].high))
    %}

    return ();
}

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

    %{
        print("compute_merkle_root_inner")
        print("i:", (ids.tree_range - ids.index))
        print(f"index_left: {ids.left_idx}, index right: {ids.right_idx}")
    %}
    
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

func double_hash_leafs{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    tree: Uint256*,
    leafs: Uint256*,
}(n_leafs: felt, tree_len: felt, index: felt) {
    if(index == n_leafs) {
        return ();
    }

    let tree_idx = tree_len - 1 - index;
    let leaf_hash = compute_leaf_hash(leafs[index]);

    %{
        def flip(val):
            val = hex(val)[2:]
            # Convert hex string to bytes
            byte_data = bytes.fromhex(val)
            num = int.from_bytes(byte_data, byteorder="little")

            return num

        leaf_hash = flip(ids.leaf_hash.low) * 2**128 + flip(ids.leaf_hash.high)
        print(f"Adding Leaf: {hex(leaf_hash)} -> Index: {ids.tree_idx}")
    %}

    assert tree[tree_len - 1 - index] = leaf_hash;

    return double_hash_leafs(
        n_leafs=n_leafs,
        tree_len=tree_len,
        index=index+1
    );
}

func hash_pair{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(left: Uint256, right: Uint256) -> Uint256 {
    alloc_locals;
    let (pair: Uint256*) = alloc();
    local is_left_smaller: felt;
    
    // ToDo: I think we can get away with handling this in a hint
    %{

        def flip(val):
            val = hex(val)[2:]
            # Convert hex string to bytes
            byte_data = bytes.fromhex(val)
            num = int.from_bytes(byte_data, byteorder="little")

            return num

        left = flip(ids.left.low) * 2**128 + flip(ids.left.high)
        right = flip(ids.right.low) * 2**128 + flip(ids.right.high)
        print(f"Left:{hex(left)}")
        print(f"RIGHT:{hex(right)}")

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

    %{
        hash_val = flip(ids.res.low) * 2**128 + flip(ids.res.high)
        print(f"Node hash: {hex(hash_val)}")
    %}

    return (res);
}


func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
} () {

    let (leafs: Uint256*) = alloc();
    let leafs_len = 5;

    assert leafs[0] = Uint256(1,0);
    assert leafs[1] = Uint256(2,0);
    assert leafs[2] = Uint256(4,0);
    assert leafs[3] = Uint256(1,0);
    assert leafs[4] = Uint256(122,0);

    compute_merkle_root{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
    }(
        leafs=leafs,
        leafs_len=leafs_len,
        index=0
    );

    return ();
}