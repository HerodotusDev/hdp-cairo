#[starknet::contract]
mod module {
    use hdp_cairo::{
        HDP,
        injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait},
        evm::{
            ETHEREUM_TESTNET_CHAIN_ID,
            header::{HeaderImpl, HeaderKey, HeaderTrait},
            storage::{StorageImpl, StorageKey, StorageTrait},
            account::{AccountImpl, AccountKey, AccountTrait},
        },
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState, 
        hdp: HDP, 
        block_number: u32,
        storage_slot: u256,
        account_address: felt252
    ) -> Array<felt252> {
        // === Injected State Logic (existing) ===
        let root = hdp.injected_state.read_injected_state_trie_root('my_trie').unwrap();
        assert!(root == 0x0, "Trie root should be 0x0");

        let value = hdp.injected_state.read_key('my_trie', 'my_key');
        assert!(value.is_none(), "Value should not exist");

        let new_root = hdp.injected_state.write_key('my_trie', 'my_key', 42);
        assert!(
            new_root == 0xf153c6cd2bc40a4ec675068562f4ddefadc23030,
            "Trie root should be 0xf153c6cd2bc40a4ec675068562f4ddefadc23030",
        );

        let value = hdp.injected_state.read_key('my_trie', 'my_key').unwrap();
        assert!(value == 42, "Value should be 42");

        // === Ethereum Sepolia Block Reading ===
        let header_key = HeaderKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: block_number.into()
        };

        // Read block header information
        let block_gas_limit = hdp.evm.header_get_gas_limit(@header_key);
        let block_timestamp = hdp.evm.header_get_timestamp(@header_key);
        let block_difficulty = hdp.evm.header_get_difficulty(@header_key);

        // === Storage Slot Reading ===
        let storage_key = StorageKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: block_number.into(),
            address: 0x396bF739f7b37D81f6CdD4571fDEF298150db88f.into(),
            storage_slot: storage_slot
        };

         let storage_value = hdp.evm.storage_get_slot(@storage_key);

        // === Account State Reading ===
        let account_key = AccountKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: block_number.into(),
            address: account_address
        };

        let account_balance = hdp.evm.account_get_balance(@account_key);
        let account_nonce = hdp.evm.account_get_nonce(@account_key);

        // Return results combining injected state and Ethereum data
        array![
            new_root,  // injected state trie root
            block_gas_limit.low.into(),  // block gas limit (low part)
            block_gas_limit.high.into(), // block gas limit (high part)
            block_timestamp.low.into(),     // block timestamp
            block_difficulty.low.into(), // block difficulty (low part)
            block_difficulty.high.into(), // block difficulty (high part)
            storage_value.low.into(),    // storage slot value (low part)
            storage_value.high.into(), // storage slot value (high part)
            account_balance.low.into(),  // account balance (low part)
            account_balance.high.into(), // account balance (high part)
            account_nonce.low.into(),    // account nonce (low part)
            account_nonce.high.into()     // account nonce (high part)
        ]
    }
}
