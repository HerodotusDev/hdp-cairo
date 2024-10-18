from contract_bootloader.provider.account_key_provider import AccountKeyEVMProvider
from contract_bootloader.memorizer.account_memorizer import MemorizerKey

EVM_PROVIDER_URL = "https://sepolia.ethereum.iosis.tech/"


def test_fetch_nonce():
    provider = AccountKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    value = provider.get_nonce(
        MemorizerKey(
            chain_id=11155111,
            block_number=1450630,
            address=0x2F14582947E292A2ECD20C430B46F2D27CFE213C,
        )
    )
    assert value == 7


def test_fetch_balance():
    provider = AccountKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    value = provider.get_balance(
        MemorizerKey(
            chain_id=11155111,
            block_number=1450630,
            address=0x2F14582947E292A2ECD20C430B46F2D27CFE213C,
        )
    )
    assert value == 432838615909525980931010


def test_fetch_state_root():
    provider = AccountKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    value = provider.get_state_root(
        MemorizerKey(
            chain_id=11155111,
            block_number=5382820,
            address=0x13CB6AE34A13A0977F4D7101EBC24B87BB23F0D5,
        )
    )
    assert value == 0x56E81F171BCC55A6FF8345E692C0F86E5B48E01B996CADC001622FB5E363B421
