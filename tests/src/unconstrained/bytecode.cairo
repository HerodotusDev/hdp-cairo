#[starknet::contract]
mod evm_account_get_bytecode_empty {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::account::{AccountImpl, AccountKey};
    use hdp_cairo::unconstrained::state::UnconstrainedMemorizerTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let _bytecode = hdp
            .evm_account_get_bytecode(
                @AccountKey {
                    chain_id: 11155111,
                    block_number: 7692344,
                    address: 0xc6e2459991BfE27cca6d86722F35da23A1E4Cb97,
                },
            );
    }
}

#[starknet::contract]
mod evm_account_get_bytecode_contract {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::account::{AccountImpl, AccountKey};
    use hdp_cairo::unconstrained::state::UnconstrainedMemorizerTrait;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let _bytecode = hdp
            .evm_account_get_bytecode(
                @AccountKey {
                    chain_id: 11155111,
                    block_number: 7692344,
                    address: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238,
                },
            );
    }
}
