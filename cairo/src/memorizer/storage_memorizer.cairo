use hdp_cairo::Memorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const STORAGE_MEMORIZER: felt252 = 2;

const STORAGE_MEMORIZER_GET_SLOT: felt252 = 0;

#[derive(Serde, Drop)]
pub struct StorageKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
    pub storage_slot: u256,
}

#[generate_trait]
pub impl AccountMemorizerImpl of AccountMemorizerTrait {
    fn get_slot(self: @Memorizer, key: StorageKey) -> u256 {
        let value = call_contract_syscall(
            STORAGE_MEMORIZER.try_into().unwrap(),
            STORAGE_MEMORIZER_GET_SLOT,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                key.block_number,
                key.address,
                key.storage_slot.low.into(),
                key.storage_slot.high.into(),
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
