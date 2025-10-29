use core::keccak::cairo_keccak;
use core::panic_with_felt252;
use hdp_cairo::EvmMemorizer;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;
use crate::UnconstrainedMemorizer;
use crate::bytecode::{ByteCode, ByteCodeLeWords, OriginalByteCodeTrait};

const UNCONSTRAINED_STORE_CONTRACT_ADDRESS: felt252 = 'unconstrained_store';

const UNCONSTRAINED_STORE_GET_BYTECODE: felt252 = 0;

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
    // TODO: @beeinger [done?]
    fn account_get_bytecode(
        self: @EvmMemorizer, key: @AccountKey, unconstrained_memorizer: @UnconstrainedMemorizer,
    ) -> ByteCode {
        let code_hash = self.account_get_code_hash(key);

        /// Bytecode as u64 le words [] +
        /// lastInputWord +
        /// lastInputNumBytes (how many bytes are in the last word)
        let mut bytecode = unconstrained_memorizer
            .call_unconstrained_memorizer(UNCONSTRAINED_STORE_GET_BYTECODE, key);

        let bytecode_le_words = Serde::<ByteCodeLeWords>::deserialize(ref bytecode).unwrap();
        let mut words_64bit = bytecode_le_words.words64bit.clone();
        let calculated_code_hash = cairo_keccak(
            ref words_64bit, bytecode_le_words.lastInputWord, bytecode_le_words.lastInputNumBytes,
        );

        if calculated_code_hash != code_hash {
            panic_with_felt252('Account: code hash mismatch');
        }

        bytecode_le_words.get_original()
    }

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

    fn call_unconstrained_memorizer(
        self: @UnconstrainedMemorizer, selector: felt252, key: @AccountKey,
    ) -> Span<felt252> {
        call_contract_syscall(
            UNCONSTRAINED_STORE_CONTRACT_ADDRESS.try_into().unwrap(),
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
