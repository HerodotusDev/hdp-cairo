from src.types import ChainInfo

namespace Layout {
    const EVM = 0;
    const STARKNET = 1;
}

func fetch_chain_info(chain_id: felt) -> (info: ChainInfo) {
    if (chain_id == 1) {
        return (
            info=ChainInfo(
                id=0x01,
                id_bytes_len=1,
                encoded_id=0x01,
                encoded_id_bytes_len=1,
                byzantium=4370000,
                layout=Layout.EVM,
            ),
        );
    }

    if (chain_id == 11155111) {
        return (
            info=ChainInfo(
                id=11155111,
                id_bytes_len=3,
                encoded_id=0x83AA36A7,
                encoded_id_bytes_len=4,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // SN_MAIN
    if (chain_id == 23448594291968334) {
        return (
            info=ChainInfo(
                id=23448594291968334,
                id_bytes_len=7,
                encoded_id=0,
                encoded_id_bytes_len=0,
                byzantium=0,
                layout=Layout.STARKNET,
            ),
        );
    }

    // SN_SEPOLIA
    if (chain_id == 393402133025997798000961) {
        return (
            info=ChainInfo(
                id=393402133025997798000961,
                id_bytes_len=10,
                encoded_id=0,
                encoded_id_bytes_len=0,
                byzantium=0,
                layout=Layout.STARKNET,
            ),
        );
    }

    assert 1 = 0;
    return (
        info=ChainInfo(
            id=0, id_bytes_len=0, encoded_id=0, encoded_id_bytes_len=0, byzantium=0, layout=-1
        ),
    );
}

func chain_id_to_layout(chain_id: felt) -> felt {
    let (info) = fetch_chain_info(chain_id=chain_id);
    return info.layout;
}
