use core::option::OptionTrait;
use example::contract::hdp_context::{Memorizer};
use starknet::syscalls::call_contract_syscall;
use starknet::{SyscallResult, SyscallResultTrait};
use core::poseidon::poseidon_hash_span;

const HEADER_MEMORIZER_ID: felt252 = 0x0;

#[derive(Serde, Drop)]
pub struct HeaderKey {
    pub chain_id: felt252,
    pub block_number: felt252,
}

pub trait HeaderKeyTrait {
    fn derive(self: HeaderKey) -> felt252;
}

pub impl HeaderKeyImpl of HeaderKeyTrait {
    fn derive(self: HeaderKey) -> felt252 {
        poseidon_hash_span(array![self.chain_id, self.block_number].span())
    }
}

#[generate_trait]
pub impl HeaderMemorizerImpl of HeaderMemorizerTrait {
    fn get_parent(self: @Memorizer, key: HeaderKey) -> u256 {
        let value = call_contract_syscall(
            0x0.try_into().unwrap(),
            HEADER_MEMORIZER_ID,
            array![
                *self.dict.segment_index,
                *self.dict.offset,
                *self.list.segment_index,
                *self.list.offset,
                key.chain_id,
                key.block_number,
            ]
                .span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
