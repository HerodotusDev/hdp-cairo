use hdp_cairo::Memorizer;
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};

const HEADER_MEMORIZER_ID: felt252 = 0x0;

const HEADER_MEMORIZER_GET_PARENT_ID: felt252 = 0x0;

#[derive(Serde, Drop)]
pub struct HeaderKey {
    pub chain_id: felt252,
    pub block_number: felt252,
}

#[generate_trait]
pub impl HeaderMemorizerImpl of HeaderMemorizerTrait {
    fn get_parent(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            HEADER_MEMORIZER_ID.try_into().unwrap(),
            HEADER_MEMORIZER_GET_PARENT_ID,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                key.chain_id,
                key.block_number,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
