#[starknet::contract]
mod module {
    use starknet::EthAddress;
    use hdp_cairo::HDP;
    use hdp_cairo::evm::ETHEREUM_TESTNET_CHAIN_ID;
    use hdp_cairo::evm::account::{AccountImpl, AccountKey, AccountTrait};
    use hdp_cairo::evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait};

    // Tornado Cash router deployment address on the Sepolia testnet.
    // Reference: https://docs.tornado.ws/general/deployments.html

    #[derive(Drop, Serde)]
    struct TxId {
        block_number: felt252,
        index: felt252,
    }

    #[storage]
    struct Storage {}

    // Main external function that performs compliance checks.
    // It verifies the user's account nonce against individual transaction nonces,
    // checks that the sender is the user, and ensures that none of the transactions
    // interacted with a forbidden address.
    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        user_address: EthAddress,
        forbidden_address: EthAddress,
        upper_bound_block_number: felt252,
        txs: Array<TxId>,
    ) -> Array<felt252> {
        // Retrieve the current nonce of the user's account as recorded in the EVM state at the
        // given block number upper bound.
        let account_nonce = hdp
            .evm
            .account_get_nonce(
                @AccountKey {
                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                    address: user_address.into(),
                    block_number: upper_bound_block_number,
                },
            );

        println!("account_nonce {:x}", account_nonce);

        let mut prev_nonce = 0;

        for tx in txs {
            // Retrieve the nonce for the current transaction.
            let nonce = hdp
                .evm
                .block_tx_get_nonce(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                );

            // Ensure that the nonce of the transaction matches the expected sequence.
            assert!(prev_nonce == nonce);

            prev_nonce += 1;

            // Retrieve the sender of the transaction.
            let sender: felt252 = hdp
                .evm
                .block_tx_get_sender(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                )
                .try_into()
                .unwrap();

            // Verify that the sender of the transaction is the given user address.
            assert!(sender == user_address.into());

            // Retrieve the receiver of the transaction.
            let receiver: felt252 = hdp
                .evm
                .block_tx_get_receiver(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                )
                .try_into()
                .unwrap();

            println!("receiver {:x}", receiver);

            // Check that the receiver is not the forbidden address.
            assert!(receiver != forbidden_address.into());
        };

        println!("final_nonce {:x}", prev_nonce);
        println!(
            "the address {:x} did not interact with {:x} up to block {:?}",
            user_address,
            forbidden_address,
            upper_bound_block_number,
        );

        // Final check: the total number of processed transactions (nonces) should match the
        // account's nonce.
        assert!(prev_nonce == account_nonce);

        array![user_address.into(), forbidden_address.into(), upper_bound_block_number]
    }
}
