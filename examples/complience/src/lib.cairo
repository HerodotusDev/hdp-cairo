#[starknet::contract]
mod module {
    use core::starknet::EthAddress;
    use hdp_cairo::HDP;
    use hdp_cairo::evm::ETHEREUM_TESTNET_CHAIN_ID;
    use hdp_cairo::evm::account::{AccountImpl, AccountKey, AccountTrait};
    use hdp_cairo::evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait};

    // Tornado cash router sepolia 0x1572AFE6949fdF51Cb3E0856216670ae9Ee160Ee
    // https://docs.tornado.ws/general/deployments.html

    #[derive(Drop, Serde)]
    struct TxId {
        block_number: felt252,
        index: felt252,
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, address: EthAddress, block_number: felt252, txs: Array<TxId>) -> felt252 {
        let account_nonce = hdp
            .evm
            .account_get_nonce(
                @AccountKey {
                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                    address: address.into(),
                    block_number: block_number,
                },
            );

        println!("account_nonce {:x}", account_nonce);

        let mut prev_nonce = 0;
        for tx in txs {
            let nonce = hdp
                .evm
                .block_tx_get_nonce(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                );
            assert!(prev_nonce == nonce);
            prev_nonce += 1;

            let sender: felt252 = hdp
                .evm
                .block_tx_get_sender(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                ).try_into().unwrap();

            assert!(sender == address.into());

            let receiver: felt252 = hdp
                .evm
                .block_tx_get_receiver(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                ).try_into().unwrap();
            
            assert!(receiver != 0x1572AFE6949fdF51Cb3E0856216670ae9Ee160Ee.try_into().unwrap());
        };

        println!("final_nonce {:x}", prev_nonce);

        assert!(prev_nonce == account_nonce);

        block_number
    }
}
