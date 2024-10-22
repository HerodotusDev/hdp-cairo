from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin

from src.types import ChainInfo
from src.decoders.evm.transaction_decoder import (
    TransactionDecoder,
    TransactionSender,
    TransactionField,
)

func test_tx_decoding_inner{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    chain_info: ChainInfo,
}(txs: felt, index: felt) {
    alloc_locals;

    if (txs == index) {
        return ();
    }

    let (rlp) = alloc();

    %{
        import os
        from dotenv import load_dotenv
        from tools.py.providers.evm.provider import EvmProvider
        from tools.py.types.evm.tx import FeltTx, Tx
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        load_dotenv()
        RPC_URL_MAINNET = os.getenv("RPC_URL_MAINNET")
        if RPC_URL_MAINNET is None:
            raise ValueError("RPC_URL_MAINNET environment variable is not set")
        provider = EvmProvider(RPC_URL_MAINNET)
        rpc_tx = provider.get_rpc_transaction_by_hash(tx_array[ids.index])
        tx = Tx.from_rpc_data(rpc_tx)
        felt_tx = FeltTx(tx)
        segments.write_arg(ids.rlp, bytes_to_8_bytes_chunks_little(tx.raw_rlp()))
    %}

    let (tx_type, local rlp_start_offset) = TransactionDecoder.open_tx_envelope(item=rlp);
    %{ assert ids.tx_type == tx.type %}

    let nonce = TransactionDecoder.get_field(
        rlp, TransactionField.NONCE, rlp_start_offset, tx_type
    );

    %{
        low, high = felt_tx.nonce(True)
        assert ids.nonce.low == low
        assert ids.nonce.high == high
    %}

    let gas_limit = TransactionDecoder.get_field(
        rlp, TransactionField.GAS_LIMIT, rlp_start_offset, tx_type
    );

    %{
        low, high = felt_tx.gas_limit(True)
        assert ids.gas_limit.low == low
        assert ids.gas_limit.high == high
    %}

    let value = TransactionDecoder.get_field(
        rlp, TransactionField.VALUE, rlp_start_offset, tx_type
    );

    %{
        low, high = felt_tx.value(True)
        assert ids.value.low == low
        assert ids.value.high == high
    %}

    let v = TransactionDecoder.get_field(rlp, TransactionField.V, rlp_start_offset, tx_type);
    %{
        low, high = felt_tx.v(True)
        assert ids.v.low == low
        assert ids.v.high == high
    %}

    let r = TransactionDecoder.get_field(rlp, TransactionField.R, rlp_start_offset, tx_type);
    %{
        low, high = felt_tx.r(True)
        assert ids.r.low == low
        assert ids.r.high == high
    %}

    let s = TransactionDecoder.get_field(rlp, TransactionField.S, rlp_start_offset, tx_type);
    %{
        low, high = felt_tx.s(True)
        assert ids.s.low == low
        assert ids.s.high == high
    %}

    local has_legacy: felt;
    %{ ids.has_legacy = 1 if ids.tx_type <= 1 else 0 %}
    if (has_legacy == 1) {
        let gas_price = TransactionDecoder.get_field(
            rlp, TransactionField.GAS_PRICE, rlp_start_offset, tx_type
        );
        %{
            low, high = felt_tx.gas_price(True)
            assert ids.gas_price.low == low
            assert ids.gas_price.high == high
        %}

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local has_eip1559: felt;
    %{ ids.has_eip1559 = 1 if ids.tx_type >= 3 else 0 %}
    if (has_eip1559 == 1) {
        let max_prio_fee_per_gas = TransactionDecoder.get_field(
            rlp, TransactionField.MAX_PRIORITY_FEE_PER_GAS, rlp_start_offset, tx_type
        );
        %{
            low, high = felt_tx.max_priority_fee_per_gas(True)
            assert ids.max_prio_fee_per_gas.low == low
            assert ids.max_prio_fee_per_gas.high == high
        %}

        let max_fee_per_gas = TransactionDecoder.get_field(
            rlp, TransactionField.MAX_FEE_PER_GAS, rlp_start_offset, tx_type
        );
        %{
            low, high = felt_tx.max_fee_per_gas(True)
            assert ids.max_fee_per_gas.low == low
            assert ids.max_fee_per_gas.high == high
        %}

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    local has_blob_versioned_hashes: felt;
    %{ ids.has_blob_versioned_hashes = 1 if ids.tx_type == 4 else 0 %}
    if (has_blob_versioned_hashes == 1) {
        let max_fee_per_blob_gas = TransactionDecoder.get_field(
            rlp, TransactionField.MAX_FEE_PER_BLOB_GAS, rlp_start_offset, tx_type
        );
        %{
            low, high = felt_tx.max_fee_per_blob_gas(True)
            assert ids.max_fee_per_blob_gas.low == low
            assert ids.max_fee_per_blob_gas.high == high
        %}

        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar bitwise_ptr = bitwise_ptr;
        tempvar pow2_array = pow2_array;
    }

    let sender = TransactionSender.derive(rlp, rlp_start_offset, tx_type);
    %{
        print(rpc_tx["from"])
        print(hex(ids.sender))
        assert ids.sender == int(rpc_tx["from"], 16)
    %}

    return test_tx_decoding_inner(txs, index + 1);
}
