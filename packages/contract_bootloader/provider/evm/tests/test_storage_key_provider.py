from contract_bootloader.provider.storage_key_provider import StorageKeyEVMProvider
from contract_bootloader.memorizer.storage_memorizer import MemorizerKey

EVM_PROVIDER_URL = "https://sepolia.ethereum.iosis.tech/"


def test_fetch_slot():
    provider = StorageKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    value = provider.get_slot(
        MemorizerKey(
            chain_id=11155111,
            block_number=6338117,
            address=0x0227628F3F023BB0B980B67D528571C95C6DAC1C,
            storage_slot=(0x0, 0x0),
        )
    )
    assert value == 0
