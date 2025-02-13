#[starknet::contract]
mod example_starkgate {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::{account::{AccountKey, AccountImpl}, ETHEREUM_TESTNET_CHAIN_ID};
    use hdp_cairo::starknet::{storage::{StorageKey, StorageImpl}, STARKNET_TESTNET_CHAIN_ID};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u128 {
        let starkgate_evm_account_key = AccountKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
            block_number: 7692344,
            address: 0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc,
        };

        let starkgate_starknet_storage_key = StorageKey {
            chain_id: STARKNET_TESTNET_CHAIN_ID,
            block_number: 517902,
            address: 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7,
            storage_slot: 0x0110e2f729c9c2b988559994a3daccd838cf52faf88e18101373e67dd061455a,
        };

        let starkgate_balance_ethereum: u256 = hdp
            .evm
            .account_get_balance(starkgate_evm_account_key);

        assert!(starkgate_balance_ethereum.high == 0x0);

        let starkgate_balance_starknet: u128 = hdp
            .starknet
            .storage_get_slot(starkgate_starknet_storage_key)
            .try_into()
            .unwrap();

        let starkgate_balance_ethereum_accuracy: u128 = starkgate_balance_ethereum.low / 1000;

        assert!(
            starkgate_balance_ethereum.low
                + starkgate_balance_ethereum_accuracy > starkgate_balance_starknet,
        );
        assert!(
            starkgate_balance_ethereum.low
                - starkgate_balance_ethereum_accuracy < starkgate_balance_starknet,
        );

        starkgate_balance_ethereum.low
    }
}
