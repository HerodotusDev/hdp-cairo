from src.hdp.types import ChainInfo

func fetch_chain_info(chain_id: felt) -> (info: ChainInfo) {
    if (chain_id == 1) {
        return (info=ChainInfo(id=0x01, id_bytes_len=1, eip155_activation=2675000));
    }

    if (chain_id == 11155111) {
        return (info=ChainInfo(id=11155111, id_bytes_len=3, eip155_activation=0));
    }

    assert 1 = 0;
    return (info=ChainInfo(id=0, id_bytes_len=0, eip155_activation=0));
}
