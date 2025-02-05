#[starknet::contract]
mod example {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptTrait, BlockReceiptKey, BlockReceiptImpl},
        evm::block_tx::{BlockTxTrait, BlockTxKey, BlockTxImpl},
    };
    use hdp_cairo::debug::print;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .block_receipt_get_cumulative_gas_used(
                    BlockReceiptKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x1a4bd13, high: 0x0 },
        );

        print(1);

        assert!(
            hdp
                .evm
                .block_tx_get_nonce(
                    BlockTxKey {
                        chain_id: 11155111, block_number: 5382809, transaction_index: 217,
                    },
                ) == u256 { low: 0x3, high: 0x0 },
        );

        print(2);
    }
}
