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

    // Optimism Mainnet
    if (chain_id == 10) {
        return (
            info=ChainInfo(
                id=10,
                id_bytes_len=1,
                encoded_id=0xa,
                encoded_id_bytes_len=4,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // Optimism Sepolia
    if (chain_id == 11155420) {
        return (
            info=ChainInfo(
                id=11155420,
                id_bytes_len=3,
                encoded_id=0x83AA37DC,
                encoded_id_bytes_len=4,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // Arbitrum Mainnet
    if (chain_id == 42161) {
        return (
            info=ChainInfo(
                id=42161,
                id_bytes_len=2,
                encoded_id=0x82A4B1,
                encoded_id_bytes_len=3,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // Arbitrum Sepolia
    if (chain_id == 421614) {
        return (
            info=ChainInfo(
                id=421614,
                id_bytes_len=3,
                encoded_id=0x83066EEE,
                encoded_id_bytes_len=4,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // Base Mainnet
    if (chain_id == 8453) {
        return (
            info=ChainInfo(
                id=8453,
                id_bytes_len=2,
                encoded_id=0x822105,
                encoded_id_bytes_len=3,
                byzantium=0,
                layout=Layout.EVM,
            ),
        );
    }

    // Base Sepolia
    if (chain_id == 84532) {
        return (
            info=ChainInfo(
                id=84532,
                id_bytes_len=3,
                encoded_id=0x83014A34,
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
