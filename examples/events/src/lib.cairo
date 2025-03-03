#[starknet::contract]
mod module {
    use core::starknet::EthAddress;
    use hdp_cairo::{HDP, evm::log::{LogImpl, LogKey, LogTrait}};

    #[storage]
    struct Storage {}

    struct EVMApprovalEvent {
        owner: EthAddress,
        spender: EthAddress,
        value: u256,
    }

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

        print!("topic0 {}", topic0);
        print!("topic1 {}", topic1);
        print!("topic2 {}", topic2);
        print!("topic3 {}", topic3);
        print!("data0 {}", data[0]);
        print!("data1 {}", data[1]);
        print!("data2 {}", data[2]);
        print!("data3 {}", data[3]);
    }
}
