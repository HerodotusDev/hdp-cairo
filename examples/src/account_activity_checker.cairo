#[starknet::contract]
mod example_account_activity_checker {
    use core::traits::TryInto;
    use hdp_cairo::{
        HDP, evm::account::{AccountImpl, AccountKey}, evm::block_tx::{BlockTxImpl, BlockTxKey},
        evm::header::{HeaderImpl, HeaderKey}, evm::storage::{StorageImpl, StorageKey},
    };

    #[storage]
    struct Storage {}

    const REQUIRED_MIN_HOLDING_PERIOD_IN_SECONDS: u256 = 604_800; // 1 week

    fn get_holding_period_in_seconds(
        hdp: @HDP,
        l1_chain_id: felt252,
        l1_start_block_number: felt252,
        l1_end_block_number: felt252,
    ) -> u256 {
        let start_block_timestamp = hdp
            .evm
            .header_get_timestamp(
                HeaderKey { chain_id: l1_chain_id, block_number: l1_start_block_number },
            );

        let end_block_timestamp = hdp
            .evm
            .header_get_timestamp(
                HeaderKey { chain_id: l1_chain_id, block_number: l1_end_block_number },
            );

        assert!(
            start_block_timestamp <= end_block_timestamp, "End block must come after start block",
        );

        let holding_period_in_seconds = end_block_timestamp - start_block_timestamp;
        holding_period_in_seconds
    }

    fn get_token_balance(
        hdp: @HDP,
        l1_chain_id: felt252,
        l1_voter_address: felt252,
        l1_voting_token_address: felt252,
        voting_token_balance_slot: u256,
        block_number: felt252,
    ) -> u256 {
        let token_balance = hdp
            .evm
            .storage_get_slot(
                StorageKey {
                    chain_id: l1_chain_id,
                    block_number: block_number,
                    address: l1_voting_token_address,
                    storage_slot: voting_token_balance_slot,
                },
            );

        token_balance
    }

    fn get_missing_txns_count(
        hdp: @HDP,
        l1_chain_id: felt252,
        l1_voter_address: felt252,
        l1_start_block_number: felt252,
        l1_end_block_number: felt252,
    ) -> (u256, u256) {
        let nonce_at_start_block: u256 = AccountImpl::account_get_nonce(
            hdp.evm,
            AccountKey {
                chain_id: l1_chain_id,
                block_number: l1_start_block_number,
                address: l1_voter_address,
            },
        );
        let nonce_at_end_block: u256 = AccountImpl::account_get_nonce(
            hdp.evm,
            AccountKey {
                chain_id: l1_chain_id, block_number: l1_end_block_number, address: l1_voter_address,
            },
        );
        if nonce_at_start_block == nonce_at_end_block {
            return (0, nonce_at_start_block);
        }
        assert!(nonce_at_end_block >= 1, "Nonce at end block must be greater than 0");
        let missing_txns_count = nonce_at_end_block - nonce_at_start_block - 1;
        (missing_txns_count, nonce_at_start_block)
    }

    fn get_tx_nonce(
        hdp: @HDP,
        expected_sender: felt252,
        l1_chain_id: felt252,
        block_number: felt252,
        tx_index: felt252,
    ) -> u256 {
        let transaction_nonce = BlockTxImpl::block_tx_get_nonce(
            hdp.evm,
            BlockTxKey { chain_id: l1_chain_id, block_number, transaction_index: tx_index },
        );

        let tx_sender = BlockTxImpl::block_tx_get_sender(
            hdp.evm,
            BlockTxKey { chain_id: l1_chain_id, block_number, transaction_index: tx_index },
        );

        assert!(tx_sender.try_into().unwrap() == expected_sender, "Unexpected transaction sender");

        transaction_nonce
    }

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        l1_chain_id: felt252,
        l1_voter_address: felt252,
        l1_voting_token_address: felt252,
        l1_voting_token_balance_slot: u256,
        l1_start_block_number: felt252,
        l1_end_block_number: felt252,
        l1_txns_block_numbers: Span<felt252>,
        l1_txns_indices: Span<felt252>,
    ) -> u256 {
        let holding_period_in_seconds = get_holding_period_in_seconds(
            @hdp, l1_chain_id.try_into().unwrap(), l1_start_block_number, l1_end_block_number,
        );
        let token_balance_at_start = get_token_balance(
            @hdp,
            l1_chain_id.try_into().unwrap(),
            l1_voter_address,
            l1_voting_token_address,
            l1_voting_token_balance_slot,
            l1_start_block_number,
        );
        let token_balance_at_end = get_token_balance(
            @hdp,
            l1_chain_id.try_into().unwrap(),
            l1_voter_address,
            l1_voting_token_address,
            l1_voting_token_balance_slot,
            l1_end_block_number,
        );
        assert!(
            token_balance_at_end >= token_balance_at_start,
            "Token balance at end must be greater than or equal to token balance at start",
        );

        let (missing_txns_count, nonce_at_start_block) = get_missing_txns_count(
            @hdp,
            l1_chain_id.try_into().unwrap(),
            l1_voter_address,
            l1_start_block_number,
            l1_end_block_number,
        );

        if missing_txns_count > 0 {
            assert!(
                l1_txns_block_numbers.len().into() == missing_txns_count,
                "Unexpected amount of transactions to check (block numbers)",
            );
            assert!(
                l1_txns_indices.len().into() == missing_txns_count,
                "Unexpected amount of transactions to check (indices)",
            );
        }
        let mut checked_tx_idx = 0;
        loop {
            if checked_tx_idx == missing_txns_count {
                break;
            }
            let expected_tx_nonce = nonce_at_start_block + checked_tx_idx;

            let tx_block_number = *l1_txns_block_numbers.at(checked_tx_idx.try_into().unwrap());
            let tx_nonce = get_tx_nonce(
                @hdp,
                l1_voter_address,
                l1_chain_id.try_into().unwrap(),
                tx_block_number,
                *l1_txns_indices.at(checked_tx_idx.try_into().unwrap()),
            );

            assert!(tx_nonce == expected_tx_nonce, "Unexpected transaction nonce");

            let token_balance_at_tx = get_token_balance(
                @hdp,
                l1_chain_id.try_into().unwrap(),
                l1_voter_address,
                l1_voting_token_address,
                l1_voting_token_balance_slot,
                tx_block_number,
            );
            assert!(token_balance_at_tx >= token_balance_at_start);

            checked_tx_idx += 1;
        };

        if holding_period_in_seconds >= REQUIRED_MIN_HOLDING_PERIOD_IN_SECONDS {
            return 1;
        }
        return 0;
    }
}
