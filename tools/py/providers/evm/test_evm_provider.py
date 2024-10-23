from hexbytes import HexBytes
import pytest
from tools.py.providers.evm.provider import EvmProvider
from tools.py.types.evm.tx import Eip155, Eip1559, Eip2930, Eip4844, LegacyTx
from tools.py.types.evm.account import Account
from tools.py.types.evm.header import (
    LegacyBlockHeader,
    BlockHeaderEIP1559,
    BlockHeaderShangai,
    BlockHeaderDencun,
)
from tools.py.types.evm.receipt import Receipt
import rlp


@pytest.fixture
def evm_provider():
    return EvmProvider(
        "https://mainnet.infura.io/v3/66dda5ed7d56432a82c8da4ac54fde8e", 1
    )


def test_legacy_header(evm_provider):
    block_number = 150001
    rpc_header = evm_provider.get_rpc_block_header_by_number(block_number)
    block_header = evm_provider.get_block_header_by_number(block_number)

    assert isinstance(block_header.header, LegacyBlockHeader)
    assert block_header.hash.hex() == rpc_header["hash"][2:]
    assert block_header.uncles_hash == HexBytes(rpc_header["sha3Uncles"])
    assert block_header.coinbase == HexBytes(rpc_header["miner"])
    assert block_header.state_root == HexBytes(rpc_header["stateRoot"])
    assert block_header.transactions_root == HexBytes(rpc_header["transactionsRoot"])
    assert block_header.receipts_root == HexBytes(rpc_header["receiptsRoot"])
    assert block_header.logs_bloom == int(rpc_header["logsBloom"], 16)
    assert block_header.difficulty == int(rpc_header["difficulty"], 16)
    assert block_header.number == int(rpc_header["number"], 16)
    assert block_header.gas_limit == int(rpc_header["gasLimit"], 16)
    assert block_header.gas_used == int(rpc_header["gasUsed"], 16)
    assert block_header.timestamp == int(rpc_header["timestamp"], 16)
    assert block_header.extra_data == HexBytes(rpc_header["extraData"])
    assert block_header.mix_hash == HexBytes(rpc_header["mixHash"])
    assert block_header.nonce == HexBytes(rpc_header["nonce"])


def test_eip1559_header(evm_provider):
    block_number = 12965001
    rpc_header = evm_provider.get_rpc_block_header_by_number(block_number)
    block_header = evm_provider.get_block_header_by_number(block_number)

    assert isinstance(block_header.header, BlockHeaderEIP1559)
    assert block_header.hash.hex() == rpc_header["hash"][2:]
    assert block_header.parent_hash == HexBytes(rpc_header["parentHash"])
    assert block_header.uncles_hash == HexBytes(rpc_header["sha3Uncles"])
    assert block_header.coinbase == HexBytes(rpc_header["miner"])
    assert block_header.state_root == HexBytes(rpc_header["stateRoot"])
    assert block_header.transactions_root == HexBytes(rpc_header["transactionsRoot"])
    assert block_header.receipts_root == HexBytes(rpc_header["receiptsRoot"])
    assert block_header.logs_bloom == int(rpc_header["logsBloom"], 16)
    assert block_header.difficulty == int(rpc_header["difficulty"], 16)
    assert block_header.number == int(rpc_header["number"], 16)
    assert block_header.gas_limit == int(rpc_header["gasLimit"], 16)
    assert block_header.gas_used == int(rpc_header["gasUsed"], 16)
    assert block_header.timestamp == int(rpc_header["timestamp"], 16)
    assert block_header.extra_data == HexBytes(rpc_header["extraData"])
    assert block_header.mix_hash == HexBytes(rpc_header["mixHash"])
    assert block_header.nonce == HexBytes(rpc_header["nonce"])
    assert block_header.base_fee_per_gas == int(rpc_header["baseFeePerGas"], 16)


def test_shanghai_header(evm_provider):
    block_number = 17034871  # A block number after the Shanghai upgrade
    rpc_header = evm_provider.get_rpc_block_header_by_number(block_number)
    block_header = evm_provider.get_block_header_by_number(block_number)

    assert isinstance(block_header.header, BlockHeaderShangai)
    assert block_header.hash.hex() == rpc_header["hash"][2:]
    assert block_header.parent_hash == HexBytes(rpc_header["parentHash"])
    assert block_header.uncles_hash == HexBytes(rpc_header["sha3Uncles"])
    assert block_header.coinbase == HexBytes(rpc_header["miner"])
    assert block_header.state_root == HexBytes(rpc_header["stateRoot"])
    assert block_header.transactions_root == HexBytes(rpc_header["transactionsRoot"])
    assert block_header.receipts_root == HexBytes(rpc_header["receiptsRoot"])
    assert block_header.logs_bloom == int(rpc_header["logsBloom"], 16)
    assert block_header.difficulty == int(rpc_header["difficulty"], 16)
    assert block_header.number == int(rpc_header["number"], 16)
    assert block_header.gas_limit == int(rpc_header["gasLimit"], 16)
    assert block_header.gas_used == int(rpc_header["gasUsed"], 16)
    assert block_header.timestamp == int(rpc_header["timestamp"], 16)
    assert block_header.extra_data == HexBytes(rpc_header["extraData"])
    assert block_header.mix_hash == HexBytes(rpc_header["mixHash"])
    assert block_header.nonce == HexBytes(rpc_header["nonce"])
    assert block_header.base_fee_per_gas == int(rpc_header["baseFeePerGas"], 16)
    assert block_header.withdrawals_root == HexBytes(rpc_header["withdrawalsRoot"])


def test_dencun_header(evm_provider):
    block_number = 19427930  # A block number after the Dencun upgrade (placeholder)
    rpc_header = evm_provider.get_rpc_block_header_by_number(block_number)
    block_header = evm_provider.get_block_header_by_number(block_number)

    assert isinstance(block_header.header, BlockHeaderDencun)
    assert block_header.hash.hex() == rpc_header["hash"][2:]
    assert block_header.parent_hash == HexBytes(rpc_header["parentHash"])
    assert block_header.uncles_hash == HexBytes(rpc_header["sha3Uncles"])
    assert block_header.coinbase == HexBytes(rpc_header["miner"])
    assert block_header.state_root == HexBytes(rpc_header["stateRoot"])
    assert block_header.transactions_root == HexBytes(rpc_header["transactionsRoot"])
    assert block_header.receipts_root == HexBytes(rpc_header["receiptsRoot"])
    assert block_header.logs_bloom == int(rpc_header["logsBloom"], 16)
    assert block_header.difficulty == int(rpc_header["difficulty"], 16)
    assert block_header.number == int(rpc_header["number"], 16)
    assert block_header.gas_limit == int(rpc_header["gasLimit"], 16)
    assert block_header.gas_used == int(rpc_header["gasUsed"], 16)
    assert block_header.timestamp == int(rpc_header["timestamp"], 16)
    assert block_header.extra_data == HexBytes(rpc_header["extraData"])
    assert block_header.mix_hash == HexBytes(rpc_header["mixHash"])
    assert block_header.nonce == HexBytes(rpc_header["nonce"])
    assert block_header.base_fee_per_gas == int(rpc_header["baseFeePerGas"], 16)
    assert block_header.withdrawals_root == HexBytes(rpc_header["withdrawalsRoot"])
    assert block_header.blob_gas_used == int(rpc_header["blobGasUsed"], 16)
    assert block_header.excess_blob_gas == int(rpc_header["excessBlobGas"], 16)
    assert block_header.parent_beacon_block_root == HexBytes(
        rpc_header["parentBeaconBlockRoot"]
    )


def test_legacy_tx(evm_provider):
    tx_hash = (
        "0x14c7b60b95719fe081cca298e0975d16d7c741c0dc2402a6af1ae7bb70c88bd9"  # Type 0
    )
    rpc_tx = evm_provider.get_rpc_transaction_by_hash(tx_hash)
    tx = evm_provider.get_transaction_by_hash(tx_hash)

    assert isinstance(tx.tx, LegacyTx)
    assert tx.sender.hex() == "7c5080988c6d91d090c23d54740f856c69450b29"
    assert tx.hash.hex() == tx_hash[2:]
    assert tx.nonce == int(rpc_tx["nonce"], 16)
    assert tx.gas_price == int(rpc_tx["gasPrice"], 16)
    assert tx.gas_limit == int(rpc_tx["gas"], 16)
    assert tx.receiver == HexBytes(rpc_tx["to"])
    assert tx.value == int(rpc_tx["value"], 16)
    assert tx.data == HexBytes(rpc_tx["input"])
    assert tx.v == int(rpc_tx["v"], 16)
    assert tx.r == HexBytes(rpc_tx["r"])
    assert tx.s == HexBytes(rpc_tx["s"])


def test_eip155_tx(evm_provider):
    tx_hash = "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51"  # Type 0 (eip155)
    rpc_tx = evm_provider.get_rpc_transaction_by_hash(tx_hash)
    tx = evm_provider.get_transaction_by_hash(tx_hash)

    assert isinstance(tx.tx, Eip155)
    assert tx.sender.hex() == "cff5c79a7d95a83b47a0fdc2d6a9c2a3f48bca29"
    assert tx.hash.hex() == tx_hash[2:]
    assert tx.nonce == int(rpc_tx["nonce"], 16)
    assert tx.gas_price == int(rpc_tx["gasPrice"], 16)
    assert tx.gas_limit == int(rpc_tx["gas"], 16)
    assert tx.receiver == HexBytes(rpc_tx["to"])
    assert tx.value == int(rpc_tx["value"], 16)
    assert tx.data == HexBytes(rpc_tx["input"])
    assert tx.v == int(rpc_tx["v"], 16)
    assert tx.r == HexBytes(rpc_tx["r"])
    assert tx.s == HexBytes(rpc_tx["s"])


def test_eip2930_tx(evm_provider):
    tx_hash = (
        "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021"  # Type 1
    )
    rpc_tx = evm_provider.get_rpc_transaction_by_hash(tx_hash)
    tx = evm_provider.get_transaction_by_hash(tx_hash)

    assert isinstance(tx.tx, Eip2930)
    assert tx.sender.hex() == "2bcb6bc69991802124f04a1114ee487ff3fad197"
    assert tx.hash.hex() == tx_hash[2:]
    assert tx.chain_id == int(rpc_tx["chainId"], 16)
    assert tx.nonce == int(rpc_tx["nonce"], 16)
    assert tx.gas_price == int(rpc_tx["gasPrice"], 16)
    assert tx.gas_limit == int(rpc_tx["gas"], 16)
    assert tx.receiver == HexBytes(rpc_tx["to"])
    assert tx.value == int(rpc_tx["value"], 16)
    assert tx.data == HexBytes(rpc_tx["input"])
    assert [element for element in tx.access_list] == [
        element for element in rpc_tx["accessList"]
    ]
    assert tx.v == int(rpc_tx["v"], 16)
    assert tx.r == HexBytes(rpc_tx["r"])
    assert tx.s == HexBytes(rpc_tx["s"])


def test_eip1559_tx(evm_provider):
    tx_hash = (
        "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b"  # Type 2
    )
    rpc_tx = evm_provider.get_rpc_transaction_by_hash(tx_hash)
    tx = evm_provider.get_transaction_by_hash(tx_hash)

    assert isinstance(tx.tx, Eip1559)
    assert tx.sender.hex() == "95222290dd7278aa3ddd389cc1e1d165cc4bafe5"
    assert tx.hash.hex() == tx_hash[2:]
    assert tx.chain_id == int(rpc_tx["chainId"], 16)
    assert tx.nonce == int(rpc_tx["nonce"], 16)
    assert tx.max_priority_fee_per_gas == int(rpc_tx["maxPriorityFeePerGas"], 16)
    assert tx.max_fee_per_gas == int(rpc_tx["maxFeePerGas"], 16)
    assert tx.gas_limit == int(rpc_tx["gas"], 16)
    assert tx.receiver == HexBytes(rpc_tx["to"])
    assert tx.value == int(rpc_tx["value"], 16)
    assert tx.data == HexBytes(rpc_tx["input"])
    assert [element for element in tx.access_list] == [
        element for element in rpc_tx["accessList"]
    ]
    assert tx.v == int(rpc_tx["v"], 16)
    assert tx.r == HexBytes(rpc_tx["r"])
    assert tx.s == HexBytes(rpc_tx["s"])


def test_eip4844_tx(evm_provider):
    tx_hash = (
        "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9"  # Type 3
    )
    rpc_tx = evm_provider.get_rpc_transaction_by_hash(tx_hash)
    tx = evm_provider.get_transaction_by_hash(tx_hash)

    assert isinstance(tx.tx, Eip4844)
    assert tx.sender.hex() == "2c169dfe5fbba12957bdd0ba47d9cedbfe260ca7"
    assert tx.hash.hex() == tx_hash[2:]
    assert tx.chain_id == int(rpc_tx["chainId"], 16)
    assert tx.nonce == int(rpc_tx["nonce"], 16)
    assert tx.max_priority_fee_per_gas == int(rpc_tx["maxPriorityFeePerGas"], 16)
    assert tx.max_fee_per_gas == int(rpc_tx["maxFeePerGas"], 16)
    assert tx.gas_limit == int(rpc_tx["gas"], 16)
    assert tx.receiver == HexBytes(rpc_tx["to"])
    assert tx.value == int(rpc_tx["value"], 16)
    assert tx.data == HexBytes(rpc_tx["input"])
    assert [element for element in tx.access_list] == [
        element for element in rpc_tx["accessList"]
    ]
    assert tx.max_fee_per_blob_gas == int(rpc_tx["maxFeePerBlobGas"], 16)
    assert [hash.hex() for hash in tx.blob_versioned_hashes] == [
        HexBytes(hash).hex() for hash in rpc_tx["blobVersionedHashes"]
    ]
    assert tx.v == int(rpc_tx["v"], 16)
    assert tx.r == HexBytes(rpc_tx["r"])
    assert tx.s == HexBytes(rpc_tx["s"])


def test_account(evm_provider):
    address = "0xF585A4aE338bC165D96E8126e8BBcAcAE725d79E"  # Example address
    account_data = evm_provider.get_rpc_account_by_address(address, 20992954)

    account = evm_provider.get_account_by_address(address, 20992954)

    assert isinstance(account, Account)
    assert account.nonce == int(account_data["nonce"], 16)
    assert account.balance == int(account_data["balance"], 16)
    assert account.storageHash == HexBytes(account_data["storageHash"])
    assert account.codeHash == HexBytes(account_data["codeHash"])


@pytest.mark.parametrize(
    "tx_hash",
    [
        "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51",  # Type 0 (eip155)
        "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021",  # Type 1
        "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b",  # Type 2
        "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9",  # Type 3
    ],
)
def test_receipt(evm_provider, tx_hash):
    rpc_receipt = evm_provider.get_rpc_receipt_by_hash(tx_hash)
    receipt = evm_provider.get_receipt_by_hash(tx_hash)

    assert isinstance(receipt, Receipt)
    assert receipt.status == (int(rpc_receipt["status"], 16) == 1)
    assert receipt.cumulative_gas_used == int(rpc_receipt["cumulativeGasUsed"], 16)
    assert receipt.bloom == HexBytes(rpc_receipt["logsBloom"])

    assert len(receipt.logs) == len(rpc_receipt["logs"])
    for log, rpc_log in zip(receipt.logs, rpc_receipt["logs"]):
        assert log.address == HexBytes(rpc_log["address"])
        assert [HexBytes(topic) for topic in log.topics] == [
            HexBytes(topic) for topic in rpc_log["topics"]
        ]
        assert log.data == HexBytes(rpc_log["data"])

    assert receipt.receipt_type == int(rpc_receipt.get("type", "0x0"), 16)

    # Test raw_rlp and from_rlp
    rlp_data = receipt.raw_rlp()
    decoded_receipt = Receipt.from_rlp(rlp_data)
    assert receipt.status == decoded_receipt.status
    assert receipt.cumulative_gas_used == decoded_receipt.cumulative_gas_used
    assert receipt.bloom == decoded_receipt.bloom
    assert len(receipt.logs) == len(decoded_receipt.logs)
    assert receipt.receipt_type == decoded_receipt.receipt_type


def test_header_rlp_roundtrip(evm_provider):
    block_numbers = [150001, 12965001, 17034871, 19427930]  # One for each header type
    for block_number in block_numbers:
        original_header = evm_provider.get_block_header_by_number(block_number)
        rlp_encoded = original_header.header.raw_rlp()
        decoded_header = type(original_header).from_rlp(rlp_encoded)

        assert original_header.hash == decoded_header.hash
        assert original_header.parent_hash == decoded_header.parent_hash
        assert original_header.uncles_hash == decoded_header.uncles_hash
        assert original_header.coinbase == decoded_header.coinbase
        assert original_header.state_root == decoded_header.state_root
        assert original_header.transactions_root == decoded_header.transactions_root
        assert original_header.receipts_root == decoded_header.receipts_root
        assert original_header.logs_bloom == decoded_header.logs_bloom
        assert original_header.difficulty == decoded_header.difficulty
        assert original_header.number == decoded_header.number
        assert original_header.gas_limit == decoded_header.gas_limit
        assert original_header.gas_used == decoded_header.gas_used
        assert original_header.timestamp == decoded_header.timestamp
        assert original_header.extra_data == decoded_header.extra_data
        assert original_header.mix_hash == decoded_header.mix_hash
        assert original_header.nonce == decoded_header.nonce

        # Check additional fields for EIP1559 and later
        if hasattr(original_header, "base_fee_per_gas"):
            assert original_header.base_fee_per_gas == decoded_header.base_fee_per_gas

        # Check additional fields for Shanghai and later
        if hasattr(original_header, "withdrawals_root"):
            assert original_header.withdrawals_root == decoded_header.withdrawals_root

        # Check additional fields for Dencun
        if hasattr(original_header, "blob_gas_used"):
            assert original_header.blob_gas_used == decoded_header.blob_gas_used
            assert original_header.excess_blob_gas == decoded_header.excess_blob_gas
            assert (
                original_header.parent_beacon_block_root
                == decoded_header.parent_beacon_block_root
            )


def test_transaction_rlp_roundtrip(evm_provider):
    tx_hashes = [
        "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b",  # Legacy
        "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51",  # EIP155
        "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021",  # EIP2930
        "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b",  # EIP1559
        "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9",  # EIP4844
    ]

    for tx_hash in tx_hashes:
        original_tx = evm_provider.get_transaction_by_hash(tx_hash)
        rlp_encoded = original_tx.raw_rlp()
        decoded_tx = type(original_tx).from_rlp(evm_provider.chain_id, rlp_encoded)

        assert original_tx.hash == decoded_tx.hash
        assert original_tx.nonce == decoded_tx.nonce
        assert original_tx.gas_limit == decoded_tx.gas_limit
        assert original_tx.receiver == decoded_tx.receiver
        assert original_tx.value == decoded_tx.value
        assert original_tx.data == decoded_tx.data
        assert original_tx.v == decoded_tx.v
        assert original_tx.r == decoded_tx.r
        assert original_tx.s == decoded_tx.s

        # Check type-specific fields
        if hasattr(original_tx, "gas_price"):
            assert original_tx.gas_price == decoded_tx.gas_price
        if hasattr(original_tx, "access_list"):
            assert original_tx.access_list == decoded_tx.access_list
        if hasattr(original_tx, "max_priority_fee_per_gas"):
            assert (
                original_tx.max_priority_fee_per_gas
                == decoded_tx.max_priority_fee_per_gas
            )
            assert original_tx.max_fee_per_gas == decoded_tx.max_fee_per_gas
        if hasattr(original_tx, "max_fee_per_blob_gas"):
            assert original_tx.max_fee_per_blob_gas == decoded_tx.max_fee_per_blob_gas
            assert original_tx.blob_versioned_hashes == decoded_tx.blob_versioned_hashes


def test_receipt_rlp_roundtrip(evm_provider):
    tx_hashes = [
        "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51",  # Type 0 (eip155)
        "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021",  # Type 1
        "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b",  # Type 2
        "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9",  # Type 3
    ]

    for tx_hash in tx_hashes:
        original_receipt = evm_provider.get_receipt_by_hash(tx_hash)
        rlp_encoded = original_receipt.raw_rlp()
        decoded_receipt = Receipt.from_rlp(rlp_encoded)

        assert original_receipt.status == decoded_receipt.status
        assert (
            original_receipt.cumulative_gas_used == decoded_receipt.cumulative_gas_used
        )
        assert original_receipt.bloom == decoded_receipt.bloom
        assert len(original_receipt.logs) == len(decoded_receipt.logs)
        for orig_log, decoded_log in zip(original_receipt.logs, decoded_receipt.logs):
            assert orig_log.address == decoded_log.address
            assert orig_log.topics == decoded_log.topics
            assert orig_log.data == decoded_log.data
        assert original_receipt.receipt_type == decoded_receipt.receipt_type
