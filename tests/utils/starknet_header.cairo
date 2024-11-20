from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.decoders.starknet.header_decoder import (
    StarknetHeaderDecoder,
    StarknetHeaderFields,
    StarknetHeaderVersion,
)

func test_starknet_header_decoding{range_check_ptr}(header_len: felt, index: felt) {
    alloc_locals;

    if (header_len == index) {
        return ();
    }

    let (header) = alloc();

    %{
        import os
        from dotenv import load_dotenv
        from tools.py.providers.starknet.provider import StarknetProvider

        load_dotenv()
        RPC_URL_STARKNET = os.getenv("RPC_URL_STARKNET")
        FEEDER_URL = os.getenv("FEEDER_URL", "https://alpha-sepolia.starknet.io/feeder_gateway/")

        if RPC_URL_STARKNET is None:
            raise ValueError("RPC_URL_STARKNET environment variable is not set")
        if FEEDER_URL is None:
            raise ValueError("STARKNET_FEEDER_URL environment variable is not set")

        provider = StarknetProvider(RPC_URL_STARKNET, FEEDER_URL)
        block_header = provider.get_block_header_by_number(block_numbers[ids.index])
        # Write header data to memory
        fields = block_header.header.to_fields()
        # Prepend the length of fields to the array
        fields.insert(0, len(fields))
        segments.write_arg(ids.header, fields)
    %}

    let header_version = StarknetHeaderDecoder.derive_header_version(header);

    // Fields common to both v1 and v2
    let (block_number) = StarknetHeaderDecoder.get_field(header, StarknetHeaderFields.BLOCK_NUMBER);
    %{ assert ids.block_number == block_header.block_number %}

    let (state_root) = StarknetHeaderDecoder.get_field(header, StarknetHeaderFields.STATE_ROOT);
    %{ assert ids.state_root == block_header.state_root %}

    let (sequencer_address) = StarknetHeaderDecoder.get_field(
        header, StarknetHeaderFields.SEQUENCER_ADDRESS
    );
    %{ assert ids.sequencer_address == block_header.sequencer_address %}

    let (block_timestamp) = StarknetHeaderDecoder.get_field(
        header, StarknetHeaderFields.BLOCK_TIMESTAMP
    );
    %{ assert ids.block_timestamp == block_header.block_timestamp %}

    let (transaction_commitment) = StarknetHeaderDecoder.get_field(
        header, StarknetHeaderFields.TRANSACTION_COMMITMENT
    );
    %{ assert ids.transaction_commitment == block_header.transaction_commitment %}

    let (event_commitment) = StarknetHeaderDecoder.get_field(
        header, StarknetHeaderFields.EVENT_COMMITMENT
    );
    %{ assert ids.event_commitment == block_header.event_commitment %}

    let (parent_block_hash) = StarknetHeaderDecoder.get_field(
        header, StarknetHeaderFields.PARENT_BLOCK_HASH
    );
    %{ assert ids.parent_block_hash == block_header.parent_block_hash %}

    // Additional fields for v2 only
    if (header_version == StarknetHeaderVersion.VERSION_2) {
        let (state_diff_commitment) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.STATE_DIFF_COMMITMENT
        );
        %{ assert ids.state_diff_commitment == block_header.state_diff_commitment %}

        let (l1_gas_price_in_wei) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.L1_GAS_PRICE_IN_WEI
        );
        %{ assert ids.l1_gas_price_in_wei == block_header.l1_gas_price_wei %}

        let (l1_gas_price_in_fri) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.L1_GAS_PRICE_IN_FRI
        );
        %{ assert ids.l1_gas_price_in_fri == block_header.l1_gas_price_fri %}

        let (l1_data_gas_price_in_wei) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.L1_DATA_GAS_PRICE_IN_WEI
        );
        %{ assert ids.l1_data_gas_price_in_wei == block_header.l1_data_gas_price_wei %}

        let (l1_data_gas_price_in_fri) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.L1_DATA_GAS_PRICE_IN_FRI
        );
        %{ assert ids.l1_data_gas_price_in_fri == block_header.l1_data_gas_price_fri %}

        let (receipts_commitment) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.RECEIPTS_COMMITMENT
        );
        %{ assert ids.receipts_commitment == block_header.receipt_commitment %}

        let (protocol_version) = StarknetHeaderDecoder.get_field(
            header, StarknetHeaderFields.PROTOCOL_VERSION
        );
        %{
            protocol_version_int = int.from_bytes(block_header.protocol_version.encode("ascii"), byteorder="big")
            assert ids.protocol_version == protocol_version_int
        %}
        assert 1 = 1;
    }

    return test_starknet_header_decoding(header_len, index + 1);
}
