#[starknet::contract]
mod module {
    use core::integer::u256;
    use hdp_cairo::HDP;
    use hdp_cairo::evm::account::{AccountImpl, AccountKey, AccountTrait};
    use hdp_cairo::evm::block_tx::{BlockTxImpl};
    use hdp_cairo::evm::{ETHEREUM_MAINNET_CHAIN_ID};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let account_nonce = hdp
            .evm
            .account_get_nonce(
                @AccountKey {
                    chain_id: ETHEREUM_MAINNET_CHAIN_ID,
                    address: 0x081bAd72D29A9F8fBa14833DC60eE6dc01c14654,
                    block_number: 21000405,
                },
            );

        // Uncomment to test simulatenous multi-evm chains support
        // let starkgate_evm_account_key = AccountKey {
        //     chain_id: ETHEREUM_TESTNET_CHAIN_ID,
        //     block_number: 7692344,
        //     address: 0x8453FC6Cd1bCfE8D4dFC069C400B433054d47bDc // l1_bridge_address
        // };
        // let _: u256 = hdp.evm.account_get_balance(@starkgate_evm_account_key);

        // https://etherscan.io/tx/0xe7efc11f5eef9c4fdaf5ab20eb93233142caad4fd48e83723a2f3eabfae1216b
        let expected_nonce: u256 = 8;
        assert!(account_nonce == expected_nonce);
    }
}
