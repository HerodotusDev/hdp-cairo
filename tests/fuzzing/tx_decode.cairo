%builtins range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.decoders.evm.header_decoder import HeaderDecoder
from packages.eth_essentials.lib.utils import pow2alloc128
from src.types import Transaction, ChainInfo
from src.decoders.evm.transaction_decoder import (
    TransactionDecoder,
    TransactionSender,
    TransactionField,
)
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
        from tests.python.test_tx_decoding import fetch_block_tx_ids, fetch_latest_block_height
        import random
        block_sample = 10
        latest_height = fetch_latest_block_height()
        selected_block = random.randrange(1, latest_height)
        print("Selected Block:", selected_block)
        tx_array = fetch_block_tx_ids(selected_block)

        if(len(tx_array) >= block_sample):
            tx_array = random.sample(tx_array, 10)
            
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
