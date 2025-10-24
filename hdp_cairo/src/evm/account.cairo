use hdp_cairo::EvmMemorizer;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

const ACCOUNT: felt252 = 1;

const ACCOUNT_GET_NONCE: felt252 = 0;
const ACCOUNT_GET_BALANCE: felt252 = 1;
const ACCOUNT_GET_STATE_ROOT: felt252 = 2;
const ACCOUNT_GET_CODE_HASH: felt252 = 3;

#[derive(Serde, Drop)]
pub struct AccountKey {
    pub chain_id: felt252,
    pub block_number: felt252,
    pub address: felt252,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    fn account_get_nonce(self: @EvmMemorizer, key: @AccountKey) -> u256 {
        let result = self.call_memorizer(ACCOUNT_GET_NONCE, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn account_get_balance(self: @EvmMemorizer, key: @AccountKey) -> u256 {
        let result = self.call_memorizer(ACCOUNT_GET_BALANCE, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn account_get_state_root(self: @EvmMemorizer, key: @AccountKey) -> u256 {
        let result = self.call_memorizer(ACCOUNT_GET_STATE_ROOT, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    fn account_get_code_hash(self: @EvmMemorizer, key: @AccountKey) -> u256 {
        let result = self.call_memorizer(ACCOUNT_GET_CODE_HASH, key);
        u256 { low: (*result[0]).try_into().unwrap(), high: (*result[1]).try_into().unwrap() }
    }
    // TODO: @beeinger
    // fn account_get_bytecode(self: @EvmMemorizer, key: @AccountKey) -> Span<u8> {
    //     let code_hash = account_get_code_hash();
    //     let bytecode = call_memorizer(self: @EvmMemorizer, selector: felt252, key: @AccountKey);
    //     assert
    //     keccak(bytecode) == code_hash;
    //     return bytecode;
    // }

    fn call_memorizer(self: @EvmMemorizer, selector: felt252, key: @AccountKey) -> Span<felt252> {
        call_contract_syscall(
            ACCOUNT.try_into().unwrap(),
            selector,
            array![
                *self.dict.segment_index, *self.dict.offset, *key.chain_id, *key.block_number,
                *key.address,
            ]
                .span(),
        )
            .unwrap_syscall()
    }
}
