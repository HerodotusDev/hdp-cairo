from src.types import ChainInfo

func fetch_chain_info(chain_id: felt) -> (info: ChainInfo) {
    if (chain_id == 1) {
        return (info=ChainInfo(id=0x01, id_bytes_len=1, byzantium=4370000));
    }

    if (chain_id == 11155111) {
        return (info=ChainInfo(id=11155111, id_bytes_len=3, byzantium=0));
    }

    assert 1 = 0;
    return (info=ChainInfo(id=0, id_bytes_len=0, byzantium=0));
}
