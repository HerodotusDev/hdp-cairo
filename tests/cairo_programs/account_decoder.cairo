%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField
from packages.eth_essentials.lib.utils import pow2alloc128
from tests.utils.account import test_account_decoding

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    local address_len: felt;

    %{
        account_array = [
            {"address": "0x46340b20830761efd32832A74d7169B29FEB9758", "block_number": 21021687}, # EOA
            {"address": "0xdAC17F958D2ee523a2206206994597C13D831ec7", "block_number": 21021687}, # ERC20
        ]

        ids.address_len = len(account_array)
    %}

    test_account_decoding{
        range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
    }(address_len, 0);

    return ();
}

