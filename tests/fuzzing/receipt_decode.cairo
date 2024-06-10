%builtins range_check bitwise keccak poseidon
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from src.decoders.header_decoder import HeaderDecoder
from packages.eth_essentials.lib.utils import pow2alloc128
from src.types import Transaction, ChainInfo
from src.decoders.transaction_decoder import TransactionDecoder, TransactionSender, TransactionField
from src.chain_info import fetch_chain_info
from tests.utils.receipt import test_receipt_decoding_inner


func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();
    let (local chain_info) = fetch_chain_info(1);

    local n_test_receipts: felt;

    %{
        from tests.python.test_receipt_decoding import fetch_block_receipt_ids, fetch_latest_block_height
        import random
        block_sample = 50
        latest_height = fetch_latest_block_height()
        selected_block = random.randrange(4370000, latest_height) #start with byzantium
        print("Selected Block:", selected_block)
        receipt_array = fetch_block_receipt_ids(selected_block)

        if(len(receipt_array) >= block_sample):
            receipt_array = random.sample(receipt_array, block_sample)
            
        ids.n_test_receipts = len(receipt_array)
    %}

    // run default tests first
    test_receipt_decoding_inner{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        chain_info=chain_info,
    }(n_test_receipts, 0);

    return ();
}


