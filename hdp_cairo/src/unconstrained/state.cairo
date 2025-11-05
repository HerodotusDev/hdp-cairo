use core::keccak::cairo_keccak;
use core::panic_with_felt252;
use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;
use crate::HDP;
use crate::bytecode::{ByteCode, ByteCodeLeWords, OriginalByteCodeTrait, U256Trait};
use crate::evm::account::{AccountKey, AccountTrait};

const UNCONSTRAINED_CONTRACT_ADDRESS: felt252 = 'unconstrained';

const BYTECODE: felt252 = 0;

#[generate_trait]
pub impl UnconstrainedMemorizerImpl of UnconstrainedMemorizerTrait {
    fn evm_account_get_bytecode(self: @HDP, key: @AccountKey) -> ByteCode {
        let calldata = array![
            *self.unconstrained.dict.segment_index, *self.unconstrained.dict.offset, *key.chain_id,
            *key.block_number, *key.address,
        ];
        let mut ret_data = call_contract_syscall(
            UNCONSTRAINED_CONTRACT_ADDRESS.try_into().unwrap(), BYTECODE, calldata.span(),
        )
            .unwrap_syscall();

        let bytecode_le_words = Serde::<ByteCodeLeWords>::deserialize(ref ret_data).unwrap();

        let code_hash = self.evm.account_get_code_hash(key);

        let mut words_64bit = bytecode_le_words.words64bit.clone();
        let calculated_code_hash = cairo_keccak(
            ref words_64bit, bytecode_le_words.lastInputWord, bytecode_le_words.lastInputNumBytes,
        )
            .reverse_endianness();

        if calculated_code_hash != code_hash {
            panic_with_felt252('Account: code hash mismatch');
        }

        bytecode_le_words.get_original()
    }
}
