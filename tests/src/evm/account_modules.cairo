#[starknet::contract]
mod evm_account_get_nonce {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountImpl, AccountKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .account_get_nonce(
                    @AccountKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                    },
                ) == u256 { low: 0x1, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod evm_account_get_balance {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountImpl, AccountKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .account_get_balance(
                    @AccountKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                    },
                ) == u256 { low: 0x2cbf225c6d700b89b34, high: 0x0 },
        );
    }
}

#[starknet::contract]
mod evm_account_get_state_root {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountImpl, AccountKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .account_get_state_root(
                    @AccountKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                    },
                ) == u256 {
                    low: 0x5b48e01b996cadc001622fb5e363b421,
                    high: 0x56e81f171bcc55a6ff8345e692c0f86e,
                },
        );
    }
}

#[starknet::contract]
mod evm_account_get_code_hash {
    use hdp_cairo::evm::account::AccountTrait;
    use hdp_cairo::{HDP, evm::account::{AccountImpl, AccountKey}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        assert!(
            hdp
                .evm
                .account_get_code_hash(
                    @AccountKey {
                        chain_id: 11155111,
                        block_number: 7692344,
                        address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                    },
                ) == u256 {
                    low: 0xe500b653ca82273b7bfad8045d85a470,
                    high: 0xc5d2460186f7233c927e7db2dcc703c0,
                },
        );
    }
}
