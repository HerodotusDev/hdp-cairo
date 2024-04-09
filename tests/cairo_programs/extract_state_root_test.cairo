%builtins output range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from src.libs.utils import pow2alloc127, word_reverse_endian_64
from src.libs.block_header import extract_state_root_little

func main{output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;

    %{
        from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async
        from tools.py.utils import bytes_to_8_bytes_chunks_little, split_128
        from dotenv import load_dotenv
        import os
        load_dotenv()
        RPC_URL = os.getenv('RPC_URL_MAINNET')
    %}
    let (pow2_array: felt*) = pow2alloc127();

    with pow2_array {
        test_batch_state_roots(from_block_number_high=100, to_block_number_low=0);
        test_batch_state_roots(from_block_number_high=14173499, to_block_number_low=14173450);
        test_batch_state_roots(from_block_number_high=17173499, to_block_number_low=17173400);
        test_batch_state_roots(from_block_number_high=12173499, to_block_number_low=12173400);
        test_batch_state_roots(from_block_number_high=11173499, to_block_number_low=11173400);
        test_batch_state_roots(from_block_number_high=10173499, to_block_number_low=10173400);
        test_batch_state_roots(from_block_number_high=9173499, to_block_number_low=9173400);
    }

    return ();
}

// Tests that the state roots are correctly extracted from the RLP arrays.
// Arguments:
// - from_block_number_high: The highest block number to fetch.
// - to_block_number_low: The lowest block number to fetch.
func test_batch_state_roots{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    from_block_number_high: felt, to_block_number_low: felt
) {
    alloc_locals;
    let (rlp_arrays: felt**) = alloc();
    let (state_roots: Uint256*) = alloc();
    local len: felt;

    %{
        fetch_block_call = fetch_blocks_from_rpc_no_async(ids.from_block_number_high, ids.to_block_number_low-1, RPC_URL)
        state_roots=[split_128(int(block.stateRoot.hex(),16)) for block in fetch_block_call]
        # print(f'state_roots={state_roots}')
        block_headers_raw_rlp = [block.raw_rlp() for block in fetch_block_call]
        rlp_arrays = [bytes_to_8_bytes_chunks_little(raw_rlp) for raw_rlp in block_headers_raw_rlp]

        ids.len = len(rlp_arrays)
        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr._reference_value+counter] = uint[0]
                memory[ptr._reference_value+counter+1] = uint[1]
                counter += 2

        segments.write_arg(ids.rlp_arrays, rlp_arrays)
        write_uint256_array(ids.state_roots, state_roots)
    %}

    test_batch_state_roots_inner(index=len - 1, rlp_arrays=rlp_arrays, state_roots=state_roots);
    return ();
}

// Checks that extract_state_root_little(rlp_arrays[index]) = state_roots[index].
// Arguments:
// - index: The index of the block number to check.
// - rlp_arrays: An array of RLP arrays.
// - state_roots: An array of state_roots.
func test_batch_state_roots_inner{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    index: felt, rlp_arrays: felt**, state_roots: Uint256*
) {
    alloc_locals;
    if (index == 0) {
        let sr_little = extract_state_root_little(rlp_arrays[index]);
        let (sr) = uint256_reverse_endian(sr_little);
        assert 0 = sr.low - state_roots[index].low;
        assert 0 = sr.high - state_roots[index].high;
        return ();
    } else {
        let sr_little = extract_state_root_little(rlp_arrays[index]);
        let (sr) = uint256_reverse_endian(sr_little);
        assert 0 = sr.low - state_roots[index].low;
        assert 0 = sr.high - state_roots[index].high;
        return test_batch_state_roots_inner(
            index=index - 1, rlp_arrays=rlp_arrays, state_roots=state_roots
        );
    }
}
