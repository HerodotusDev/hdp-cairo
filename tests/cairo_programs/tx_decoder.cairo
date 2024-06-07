%builtins range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.decoders.header_decoder import HeaderDecoder
from packages.eth_essentials.lib.utils import pow2alloc128
from src.types import Transaction, ChainInfo
from src.decoders.transaction_decoder import TransactionDecoder, TransactionSender, TransactionField
from src.chain_info import fetch_chain_info
from tests.utils.tx import test_tx_decoding_inner
func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    let (local chain_info) = fetch_chain_info(1);

    local n_test_txs: felt;

    %{
        tx_array = [
            "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b", # Type 0
            "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51", # Type 0 (eip155)
            "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021", # Type 1
            "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b", # Type 2
            "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9", # Type 3
            # Other edge cases that have failed before
            "0x15306e5f15afc5d178d705155bd38d70504795686f5f75f3d759ff3fb7fcb61d",
            "0x371882ee00ff668ca6bf9b1ec37fda5e1fa3a4d0b0f2fb4ef26611f1b1603d3e",
            "0xa10d0d5a82894137f33b85e8f40a028eb740acc3dd3b98ed85c16e8d5d57a803",
            "0xd675eaa76156b865c8d0aa1556dd08b0ed0bc2dc6531fc168f3d623aaa093230",
            "0x66319691b7c3a1773496c14f68164aef3988ecfdde04081c771c1930369a48e8",
            "0xf7635229a06e479acce3f9e9a4bdf7b34ecbfac735c21bf7f0300c292c6ff188"
        ]

        ids.n_test_txs = len(tx_array)
    %}

    // run default tests first
    test_tx_decoding_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        chain_info=chain_info,
    }(n_test_txs, 0);

    return ();
}
