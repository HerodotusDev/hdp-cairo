#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::evm::block_receipt::BlockReceiptTrait;
    use hdp_cairo::evm::{ETHEREUM_TESTNET_CHAIN_ID, block_receipt::BlockReceiptKey};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let key = BlockReceiptKey {
            chain_id: ETHEREUM_TESTNET_CHAIN_ID, block_number: 7692344, transaction_index: 180,
        };

        let topic0 = hdp.evm.block_receipt_get_topic2(key);
        println!("topic0 {}", topic0.low);
        println!("topic0 {}", topic0.high);
    }
}
