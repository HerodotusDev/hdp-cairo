import pytest
from tools.py.providers.starknet.provider import StarknetProvider
from tools.py.types.starknet.header import (
    StarknetHeader,
    LegacyStarknetBlock,
    StarknetBlockV0_13_2,
)
import os
from dotenv import load_dotenv


@pytest.fixture
def starknet_provider():
    load_dotenv()
    PROVIDER_URL_STARKNET = os.getenv("PROVIDER_URL_STARKNET")
    FEEDER_URL = os.getenv(
        "FEEDER_URL", "https://alpha-sepolia.starknet.io/feeder_gateway/"
    )
    return StarknetProvider(
        PROVIDER_URL_STARKNET,
        FEEDER_URL,
    )


def test_legacy_header(starknet_provider):
    block_number = 80000  # Legacy block
    feeder_header = starknet_provider.send_feeder_request(
        "get_block", {"blockNumber": block_number}
    )
    block_header = starknet_provider.get_block_header_by_number(block_number)
    print(block_header)

    # Verify header type
    assert isinstance(block_header.header, LegacyStarknetBlock)

    # Verify all fields match feeder data
    assert block_header.hash == int(feeder_header["block_hash"], 16)
    assert block_header.parent_block_hash == int(feeder_header["parent_block_hash"], 16)
    assert block_header.block_number == int(feeder_header["block_number"])
    assert block_header.state_root == int(feeder_header["state_root"], 16)
    assert block_header.sequencer_address == int(feeder_header["sequencer_address"], 16)
    assert block_header.block_timestamp == int(feeder_header["timestamp"])
    assert block_header.transaction_count == len(feeder_header["transactions"])
    assert block_header.transaction_commitment == int(
        feeder_header["transaction_commitment"], 16
    )
    assert block_header.event_commitment == int(feeder_header["event_commitment"], 16)


def test_v13_2_header(starknet_provider):
    block_number = 100000  # v13.2 block
    feeder_header = starknet_provider.send_feeder_request(
        "get_block", {"blockNumber": block_number}
    )
    block_header = starknet_provider.get_block_header_by_number(block_number)

    # Verify header type
    assert isinstance(block_header.header, StarknetBlockV0_13_2)

    # Verify all fields match feeder data
    assert block_header.hash == int(feeder_header["block_hash"], 16)
    assert block_header.parent_block_hash == int(feeder_header["parent_block_hash"], 16)
    assert block_header.block_number == int(feeder_header["block_number"])
    assert block_header.state_root == int(feeder_header["state_root"], 16)
    assert block_header.sequencer_address == int(feeder_header["sequencer_address"], 16)
    assert block_header.block_timestamp == int(feeder_header["timestamp"])
    assert block_header.transaction_count == len(feeder_header["transactions"])
    assert block_header.transaction_commitment == int(
        feeder_header["transaction_commitment"], 16
    )
    assert block_header.event_commitment == int(feeder_header["event_commitment"], 16)
    assert block_header.protocol_version == feeder_header["starknet_version"]

    # New fields in v13.2
    assert block_header.l1_gas_price_wei == int(
        feeder_header["l1_gas_price"]["price_in_wei"], 16
    )
    assert block_header.l1_gas_price_fri == int(
        feeder_header["l1_gas_price"]["price_in_fri"], 16
    )
    assert block_header.l1_data_gas_price_wei == int(
        feeder_header["l1_data_gas_price"]["price_in_wei"], 16
    )
    assert block_header.l1_data_gas_price_fri == int(
        feeder_header["l1_data_gas_price"]["price_in_fri"], 16
    )
    assert block_header.l1_da_mode == feeder_header["l1_da_mode"]


def test_header_transition_period(starknet_provider):
    """Test blocks around the transition period from legacy to v13.2"""
    # Test a few blocks before and after transition
    pre_transition_blocks = [86308, 86309, 86310]
    post_transition_blocks = [86311, 86312, 86313]

    # Pre-transition blocks should be legacy
    for block_number in pre_transition_blocks:
        block_header = starknet_provider.get_block_header_by_number(block_number)
        assert isinstance(block_header.header, LegacyStarknetBlock)

        # Verify hash computation
        feeder_header = starknet_provider.send_feeder_request(
            "get_block", {"blockNumber": block_number}
        )
        assert block_header.hash == int(feeder_header["block_hash"], 16)

    # Post-transition blocks should be v13.2
    for block_number in post_transition_blocks:
        block_header = starknet_provider.get_block_header_by_number(block_number)
        assert isinstance(block_header.header, StarknetBlockV0_13_2)

        # Verify hash computation
        feeder_header = starknet_provider.send_feeder_request(
            "get_block", {"blockNumber": block_number}
        )
        assert block_header.hash == int(feeder_header["block_hash"], 16)
