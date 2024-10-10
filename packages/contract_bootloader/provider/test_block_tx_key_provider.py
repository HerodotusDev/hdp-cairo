from contract_bootloader.provider.block_tx_key_provider import BlockTxKeyEVMProvider
from contract_bootloader.memorizer.block_tx_memorizer import MemorizerKey

EVM_PROVIDER_URL = "https://sepolia.ethereum.iosis.tech/"


def test_fetch_slot():
    provider = BlockTxKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    value = provider.get_gas_price(
        MemorizerKey(chain_id=11155111, block_number=6338117, index=3)
    )
    assert value == 18886516632
