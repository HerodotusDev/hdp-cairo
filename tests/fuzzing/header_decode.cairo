%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from packages.eth_essentials.lib.utils import pow2alloc128
from tests.utils.header import test_header_decoding

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    local block_numbers_len: felt;

    %{
        from tests.python.test_tx_decoding import fetch_latest_block_height
        import random

        sample_size = 25
        max_block_height = fetch_latest_block_height()

        block_numbers = []
        while len(block_numbers) < sample_size:
            block_numbers.append(random.randrange(1, max_block_height))

        ids.block_numbers_len = len(block_numbers)
    %}

    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_numbers_len, 0);

    return ();
}
