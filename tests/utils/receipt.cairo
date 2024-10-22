from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin

from src.types import ChainInfo
from src.decoders.evm.receipt_decoder import ReceiptDecoder, ReceiptField

func test_receipt_decoding_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    chain_info: ChainInfo,
}(receipts: felt, index: felt) {
    alloc_locals;

    if (receipts == index) {
        return ();
    }

    let (rlp) = alloc();

    local block_number: felt;
    %{
        import os
        from dotenv import load_dotenv
        from tools.py.providers.evm.provider import EvmProvider
        from tools.py.types.evm.receipt import FeltReceipt, Receipt
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        load_dotenv()
        RPC_URL_MAINNET = os.getenv("RPC_URL_MAINNET")
        if RPC_URL_MAINNET is None:
            raise ValueError("RPC_URL_MAINNET environment variable is not set")
        provider = EvmProvider(RPC_URL_MAINNET)
        rpc_receipt = provider.get_rpc_receipt_by_hash(receipt_array[ids.index])
        ids.block_number = int(rpc_receipt["blockNumber"], 16)
        receipt = Receipt.from_rpc_data(rpc_receipt)
        felt_receipt = FeltReceipt(receipt)

        segments.write_arg(ids.rlp, bytes_to_8_bytes_chunks_little(receipt.raw_rlp()))
    %}

    let (tx_type, local rlp_start_offset) = ReceiptDecoder.open_receipt_envelope(item=rlp);
    %{ assert ids.tx_type == receipt.type, "type test failed" %}

    let status = ReceiptDecoder.get_field(
        rlp, ReceiptField.SUCCESS, rlp_start_offset, tx_type, block_number
    );

    %{
        low, high = felt_receipt.status(True)
        assert ids.status.low == low
        assert ids.status.high == high
    %}

    let cumulative_gas_used = ReceiptDecoder.get_field(
        rlp, ReceiptField.CUMULATIVE_GAS_USED, rlp_start_offset, tx_type, block_number
    );
    %{
        low, high = felt_receipt.cumulative_gas_used(True)
        assert ids.cumulative_gas_used.low == low
        assert ids.cumulative_gas_used.high == high
    %}

    return test_receipt_decoding_inner(receipts, index + 1);
}
