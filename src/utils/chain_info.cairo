// ============================================================================
// Chain Info Utilities
// ============================================================================
// Provides chain metadata (layout, encoding, byzantium block) for known chains
// and exposes helpers for mapping chain IDs to layouts.
from src.types import ChainInfo

namespace Layout {
    const EVM = 0;
    const STARKNET = 1;
}

// ChainInfo fields:
// - id: Numeric chain ID (e.g., 1 for Ethereum Mainnet)
// - id_bytes_len: Number of bytes needed to represent the chain ID
// - encoded_id: RLP-encoded chain ID (for EIP-155 signature encoding)
// - encoded_id_bytes_len: Length of the RLP-encoded chain ID
// - byzantium: Block number where Byzantium fork activated (0 = at genesis)
// - layout: Chain layout type (EVM = 0, Starknet = 1)
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

    with_attr error_message("fetch_chain_info: unsupported chain_id {chain_id}") {
        assert 1 = 0;
    }
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
