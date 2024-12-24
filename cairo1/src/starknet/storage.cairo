use hdp_cairo::StarknetMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const STORAGE: felt252 = 1;
const STORAGE_GET_SLOT: felt252 = 0;

#[derive(Serde, Drop)]
pub struct StorageKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
    pub storage_slot: felt252,
}

#[generate_trait]
pub impl StorageImpl of StorageTrait {
    fn storage_get_slot(self: @StarknetMemorizer, key: StorageKey) -> felt252 {
        let value = call_contract_syscall(
            STORAGE.try_into().unwrap(),
            STORAGE_GET_SLOT,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                key.block_number,
                key.address,
                key.storage_slot,
            ]
                .span()
        )
            .unwrap_syscall();
        (*value[0]).try_into().unwrap()
    }
}
