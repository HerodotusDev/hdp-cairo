pub mod bloom;

#[starknet::contract]
mod module {
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let key = BlockReceiptKey {
            chain_id: 11155111, block_number: 7692344, transaction_index: 183,
        };

        let bloom = hdp.evm.block_receipt_get_bloom(@key);
        print!("bloom {:?}", bloom);

        array![0]
    }
}
