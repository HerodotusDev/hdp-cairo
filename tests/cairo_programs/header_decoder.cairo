%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField
from packages.eth_essentials.lib.utils import pow2alloc128
from tests.utils.header import test_header_decoding

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    local block_numbers_len: felt;

    %{
        block_numbers = [
            150001, # Homestead
            12965001, # London (EIP-1559)
            17034871, # Shanghai
            19427930, # Dencun
            # random block numbers
            3549319,
            6374469,
            18603628,
            7244939
        ]

        ids.block_numbers_len = len(block_numbers)
    %}

    test_header_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(block_numbers_len, 0);

    return ();
}
