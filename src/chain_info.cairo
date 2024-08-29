from src.types import ChainInfo
from src.memorizers.reader import MemorizerLayout


func fetch_chain_info(chain_id: felt) -> (info: ChainInfo) {
    if (chain_id == 1) {
        return (info=ChainInfo(id=0x01, id_bytes_len=1, byzantium=4370000, memorizer_layout=MemorizerLayout.EVM));
    }

    if (chain_id == 11155111) {
        return (info=ChainInfo(id=11155111, id_bytes_len=3, byzantium=0, memorizer_layout=MemorizerLayout.EVM));
    }

    // SN_MAIN 
    if (chain_id == 23448594291968334) {
        return (info=ChainInfo(id=23448594291968334, id_bytes_len=7, byzantium=0, memorizer_layout=MemorizerLayout.STARKNET));
    }

    // SN_SEPOLIA
    if (chain_id == 393402133025997798000961) {
        return (info=ChainInfo(id=393402133025997798000961, id_bytes_len=10, byzantium=0, memorizer_layout=MemorizerLayout.STARKNET));
    }

    assert 1 = 0;
    return (info=ChainInfo(id=0, id_bytes_len=0, byzantium=0, memorizer_layout=-1));
}

func chain_id_to_memorizer_layout(chain_id: felt) -> felt {
    let (info) = fetch_chain_info(chain_id=chain_id);
    return info.memorizer_layout;
}
