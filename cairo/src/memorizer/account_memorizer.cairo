use hdp_cairo::Memorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const ACCOUNT_MEMORIZER_ID: felt252 = 0x1;

const ACCOUNT_MEMORIZER_GET_BALANCE_ID: felt252 = 0x0;

#[derive(Serde, Drop)]
pub struct AccountKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
}

#[generate_trait]
pub impl AccountMemorizerImpl of AccountMemorizerTrait {
    fn get_balance(self: @Memorizer, key: AccountKey) -> u256 {
        let value = call_contract_syscall(
            ACCOUNT_MEMORIZER_ID.try_into().unwrap(),
            ACCOUNT_MEMORIZER_GET_BALANCE_ID,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                *self.list.segment_index,
                *self.list.offset,
                key.chain_id,
                key.block_number,
                key.address,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
