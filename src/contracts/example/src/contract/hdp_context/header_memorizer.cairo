use core::option::OptionTrait;
use example::contract::hdp_context::{Memorizer};
use starknet::syscalls::call_contract_syscall;
use starknet::{contract_address::contract_address_const, SyscallResult, SyscallResultTrait};
use core::poseidon::poseidon_hash_span;

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
            contract_address_const::<0>(),
            0x0,
            array![*self.segment, *self.offset, key.derive()].span()
        )
            .unwrap_syscall();
        u256 { low: (*value[0]).try_into().unwrap(), high: (*value[1]).try_into().unwrap() }
    }
}
