use hdp_cairo::EvmMemorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResultTrait};

const STORAGE: felt252 = 2;

const STORAGE_GET_SLOT: felt252 = 0;

#[derive(Serde, Drop)]
pub struct StorageKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
    pub storage_slot: u256,
}

#[generate_trait]
pub impl StorageImpl of StorageTrait {
    fn storage_get_slot(self: @EvmMemorizer, key: StorageKey) -> u256 {
        let result = self.call_memorizer(key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }

    fn call_memorizer(self: @EvmMemorizer, key: StorageKey) -> Span<felt252> {
        call_contract_syscall(
            STORAGE.try_into().unwrap(),
            STORAGE_GET_SLOT,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                key.block_number,
                key.address,
                key.storage_slot.high.into(),
                key.storage_slot.low.into(),
            ]
                .span(),
        )
            .unwrap_syscall()
    }
}
