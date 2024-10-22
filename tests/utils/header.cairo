from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField

func test_header_decoding{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    header_len: felt, index: felt
) {
    alloc_locals;

    if (header_len == index) {
        return ();
    }

    let (rlp) = alloc();
    local header_type: felt;

    %{
        import os
        from dotenv import load_dotenv
        from tools.py.providers.evm.provider import EvmProvider
        from tools.py.types.evm.header import FeltBlockHeader, BlockHeader
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        load_dotenv()
        RPC_URL_MAINNET = os.getenv("RPC_URL_MAINNET")
        if RPC_URL_MAINNET is None:
            raise ValueError("RPC_URL_MAINNET environment variable is not set")
        provider = EvmProvider(RPC_URL_MAINNET)
        rpc_header = provider.get_rpc_block_header_by_number(block_numbers[ids.index])
        header = BlockHeader.from_rpc_data(rpc_header)
        felt_header = FeltBlockHeader(header)
        ids.header_type = header.type
        segments.write_arg(ids.rlp, bytes_to_8_bytes_chunks_little(header.raw_rlp()))
    %}

    let parent_hash = HeaderDecoder.get_field(rlp, HeaderField.PARENT);
    %{
        low, high = felt_header.parent_hash(True)
        assert ids.parent_hash.low == low
        assert ids.parent_hash.high == high
    %}

    let uncles_hash = HeaderDecoder.get_field(rlp, HeaderField.UNCLE);
    %{
        low, high = felt_header.uncles_hash(True)
        assert ids.uncles_hash.low == low
        assert ids.uncles_hash.high == high
    %}

    let coinbase = HeaderDecoder.get_field(rlp, HeaderField.COINBASE);
    %{
        low, high = felt_header.coinbase(True)
        assert ids.coinbase.low == low
        assert ids.coinbase.high == high
    %}

    let state_root = HeaderDecoder.get_field(rlp, HeaderField.STATE_ROOT);
    %{
        low, high = felt_header.state_root(True)
        assert ids.state_root.low == low
        assert ids.state_root.high == high
    %}

    let tx_root = HeaderDecoder.get_field(rlp, HeaderField.TRANSACTION_ROOT);
    %{
        low, high = felt_header.transactions_root(True)
        assert ids.tx_root.low == low
        assert ids.tx_root.high == high
    %}

    let receipts_root = HeaderDecoder.get_field(rlp, HeaderField.RECEIPT_ROOT);
    %{
        low, high = felt_header.receipts_root(True)
        assert ids.receipts_root.low == low
        assert ids.receipts_root.high == high
    %}

    let difficulty = HeaderDecoder.get_field(rlp, HeaderField.DIFFICULTY);
    %{
        low, high = felt_header.difficulty(True)
        assert ids.difficulty.low == low
        assert ids.difficulty.high == high
    %}

    let number = HeaderDecoder.get_field(rlp, HeaderField.NUMBER);
    %{
        low, high = felt_header.number(True)
        assert ids.number.low == low
        assert ids.number.high == high
    %}

    let gas_limit = HeaderDecoder.get_field(rlp, HeaderField.GAS_LIMIT);
    %{
        low, high = felt_header.gas_limit(True)
        assert ids.gas_limit.low == low
        assert ids.gas_limit.high == high
    %}

    let gas_used = HeaderDecoder.get_field(rlp, HeaderField.GAS_USED);
    %{
        low, high = felt_header.gas_used(True)
        assert ids.gas_used.low == low
        assert ids.gas_used.high == high
    %}

    let timestamp = HeaderDecoder.get_field(rlp, HeaderField.TIMESTAMP);
    %{
        low, high = felt_header.timestamp(True)
        assert ids.timestamp.low == low
        assert ids.timestamp.high == high
    %}

    let mix_hash = HeaderDecoder.get_field(rlp, HeaderField.MIX_HASH);
    %{
        low, high = felt_header.mix_hash(True)
        assert ids.mix_hash.low == low
        assert ids.mix_hash.high == high
    %}

    let nonce = HeaderDecoder.get_field(rlp, HeaderField.NONCE);
    %{
        low, high = felt_header.nonce(True)
        assert ids.nonce.low == low
        assert ids.nonce.high == high
    %}

    local impl_london: felt;
    %{ ids.impl_london = 1 if ids.header_type >= 1 else 0 %}

    if (impl_london == 1) {
        let base_fee_per_gas = HeaderDecoder.get_field(rlp, HeaderField.BASE_FEE_PER_GAS);
        %{
            low, high = felt_header.base_fee_per_gas(True)
            assert ids.base_fee_per_gas.low == low
            assert ids.base_fee_per_gas.high == high
        %}
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local impl_shanghai: felt;
    %{ ids.impl_shanghai = 1 if ids.header_type >= 2 else 0 %}
    if (impl_shanghai == 1) {
        let withdrawls_root = HeaderDecoder.get_field(rlp, HeaderField.WITHDRAWALS_ROOT);
        %{
            low, high = felt_header.withdrawals_root(True)
            assert ids.withdrawls_root.low == low
            assert ids.withdrawls_root.high == high
        %}
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local impl_dencun: felt;
    %{ ids.impl_dencun = 1 if ids.header_type >= 3 else 0 %}

    if (impl_dencun == 1) {
        let blob_gas_used = HeaderDecoder.get_field(rlp, HeaderField.BLOB_GAS_USED);
        %{
            low, high = felt_header.blob_gas_used(True)
            assert ids.blob_gas_used.low == low
            assert ids.blob_gas_used.high == high
        %}

        let excess_blob_gas = HeaderDecoder.get_field(rlp, HeaderField.EXCESS_BLOB_GAS);
        %{
            low, high = felt_header.excess_blob_gas(True)
            assert ids.excess_blob_gas.low == low
            assert ids.excess_blob_gas.high == high
        %}

        let parent_beacon_root = HeaderDecoder.get_field(rlp, HeaderField.PARENT_BEACON_BLOCK_ROOT);
        %{
            low, high = felt_header.parent_beacon_block_root(True)
            assert ids.parent_beacon_root.low == low
            assert ids.parent_beacon_root.high == high
        %}
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    return test_header_decoding(header_len=header_len, index=index + 1);
}
