#[starknet::contract]
mod get_status {
    use hdp_cairo::evm::block_receipt::BlockReceiptTrait;
    use hdp_cairo::{HDP, evm::block_receipt::{BlockReceiptKey, BlockReceiptImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_receipt_get_status(
                BlockReceiptKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}

#[starknet::contract]
mod get_cumulative_gas_used {
    use hdp_cairo::evm::block_receipt::BlockReceiptTrait;
    use hdp_cairo::{HDP, evm::block_receipt::{BlockReceiptKey, BlockReceiptImpl}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP, block_number: u32, index: u32) -> u256 {
        hdp
            .evm
            .block_receipt_get_cumulative_gas_used(
                BlockReceiptKey {
                    chain_id: 11155111, block_number: block_number.into(), index: index.into()
                }
            )
    }
}
