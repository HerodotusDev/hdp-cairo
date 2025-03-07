pub mod bloom;

#[starknet::contract]
mod module {
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let key = LogKey {
            chain_id: 11155111, block_number: 7692344, transaction_index: 183, log_index: 2,
        };

        let topic0 = hdp.evm.log_get_topic0(@key).into();
        let topic1 = hdp.evm.log_get_topic1(@key).into();
        let topic2 = hdp.evm.log_get_topic2(@key).into();
        let topic3 = hdp.evm.log_get_topic3(@key).into();
        let data = hdp.evm.log_get_data(@key);

        print!("topic0 {:x}", topic0);
        print!("topic1 {:x}", topic1);
        print!("topic2 {:x}", topic2);
        print!("topic3 {:x}", topic3);
        print!("data {:?}", data);
    }
}
