from contract_bootloader.provider.header_key_provider import HeaderKeyEVMProvider
from contract_bootloader.memorizer.header_memorizer import MemorizerKey

EVM_PROVIDER_URL = "https://sepolia.ethereum.iosis.tech/"


def test_fetch_block():
    provider = HeaderKeyEVMProvider(provider_url=EVM_PROVIDER_URL)
    block = provider.get_block(MemorizerKey(chain_id=11155111, block_number=10000))

    assert int(block["nonce"].hex(), 16) == 0xC7FAAF72B5AE7B05
    assert (
        int(block["parentHash"].hex(), 16)
        == 0x1BF8C6858EF8AD67DD7EACEB34D99A3277C7B6E4A45A3C2A9135489B2586A8DB
    )
    assert (
        int(block["sha3Uncles"].hex(), 16)
        == 0x1DCC4DE8DEC75D7AAB85B567B6CCD41AD312451B948A7413F0A142FD40D49347
    )
    assert (
        int(block["stateRoot"].hex(), 16)
        == 0x011416CBB9D766DC4FCABBB79515A1CAA4676EC62213B0EA8B346E807F8BCAEC
    )
