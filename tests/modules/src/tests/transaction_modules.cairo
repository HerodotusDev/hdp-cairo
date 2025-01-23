#[starknet::contract]
mod transaction_get_nonce {
    use hdp_cairo::{HDP, evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_tx_get_nonce(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x3, high: 0x0 },
        );
    }
}
