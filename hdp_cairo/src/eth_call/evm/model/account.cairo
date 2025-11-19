use core::dict::{Felt252Dict, Felt252DictTrait};
use core::num::traits::Zero;
use hdp_cairo::HDP;
use starknet::{ContractAddress, EthAddress};
use crate::eth_call::evm::test_utils::test_address;
use crate::eth_call::hdp_backend::{fetch_balance, fetch_bytecode, fetch_code_hash, fetch_nonce};
use crate::eth_call::utils::constants::EMPTY_KECCAK;
use crate::eth_call::utils::traits::bytes::U8SpanExTrait;
use super::TimeAndSpace;

#[derive(Drop)]
struct AccountBuilder {
    hdp: Option<@HDP>,
    time_and_space: @TimeAndSpace,
    account: Account,
}

#[generate_trait]
impl AccountBuilderImpl of AccountBuilderTrait {
    fn new(
        address: EthAddress, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
    ) -> AccountBuilder {
        AccountBuilder {
            hdp,
            time_and_space,
            account: Account {
                address: address,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                nonce: 0,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            },
        }
    }

    #[inline(always)]
    fn fetch_balance(mut self: AccountBuilder) -> AccountBuilder {
        self.account.balance = fetch_balance(self.hdp, self.time_and_space, @self.account.address);
        self
    }

    #[inline(always)]
    fn fetch_nonce(mut self: AccountBuilder) -> AccountBuilder {
        self.account.nonce = fetch_nonce(self.hdp, self.time_and_space, @self.account.address);
        self
    }

    /// Loads the bytecode of a ContractAccount from Kakarot Core's contract storage into a
    /// Span<u8>.
    /// # Arguments
    /// * `self` - The address of the Contract Account to load the bytecode from
    /// # Returns
    /// * The bytecode of the Contract Account as a ByteArray
    #[inline(always)]
    fn fetch_bytecode(mut self: AccountBuilder) -> AccountBuilder {
        self.account.code = fetch_bytecode(self.hdp, self.time_and_space, @self.account.address);
        self
    }

    #[inline(always)]
    fn fetch_code_hash(mut self: AccountBuilder) -> AccountBuilder {
        self
            .account
            .code_hash = fetch_code_hash(self.hdp, self.time_and_space, @self.account.address);
        self
    }

    #[inline(always)]
    fn build(self: AccountBuilder) -> Account {
        self.account
    }
}

#[derive(Copy, Drop, PartialEq, Debug)]
pub struct Account {
    pub address: EthAddress,
    pub code: Span<u8>,
    pub code_hash: u256,
    pub nonce: u64,
    pub balance: u256,
    pub selfdestruct: bool,
    pub is_created: bool,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    /// Fetches an account from Starknet
    ///
    /// # Arguments
    /// * `address` - The address of the account to fetch`
    ///
    /// # Returns
    /// The fetched account if it existed, otherwise `None`.
    fn fetch(
        evm_address: EthAddress, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
    ) -> Option<Account> {
        Option::Some(
            AccountBuilderTrait::new(evm_address, hdp, time_and_space)
                .fetch_nonce()
                .fetch_bytecode()
                .fetch_balance()
                .fetch_code_hash()
                .build(),
        )
    }


    /// Returns whether an account exists at the given address by checking
    /// whether it has code or a nonce.
    ///
    /// # Arguments
    ///
    /// * `account` - The instance of the account to check.
    ///
    /// # Returns
    ///
    /// `true` if an account exists at this address (has code or nonce), `false` otherwise.
    #[inline(always)]
    fn has_code_or_nonce(self: @Account) -> bool {
        return !(*self.code).is_empty() || *self.nonce != 0;
    }

    #[inline(always)]
    fn is_created(self: @Account) -> bool {
        *self.is_created
    }

    #[inline(always)]
    fn set_created(ref self: Account, is_created: bool) {
        self.is_created = is_created;
    }

    #[inline(always)]
    fn balance(self: @Account) -> u256 {
        *self.balance
    }

    #[inline(always)]
    fn set_balance(ref self: Account, value: u256) {
        self.balance = value;
    }

    #[inline(always)]
    fn address(self: @Account) -> EthAddress {
        *self.address
    }

    #[inline(always)]
    fn evm_address(self: @Account) -> EthAddress {
        *self.address
    }

    /// Returns the bytecode of the EVM account (EOA or CA)
    #[inline(always)]
    fn bytecode(self: @Account) -> Span<u8> {
        *self.code
    }

    #[inline(always)]
    fn code_hash(self: @Account) -> u256 {
        *self.code_hash
    }


    /// Sets the nonce of the Account
    /// # Arguments
    /// * `self` The Account to set the nonce on
    /// * `nonce` The new nonce
    #[inline(always)]
    fn set_nonce(ref self: Account, nonce: u64) {
        self.nonce = nonce;
    }

    #[inline(always)]
    fn nonce(self: @Account) -> u64 {
        *self.nonce
    }

    /// Sets the code of the Account
    /// Also sets the code hash to be synced with the code
    /// # Arguments
    /// * `self` The Account to set the code on
    /// * `code` The new code
    #[inline(always)]
    fn set_code(ref self: Account, code: Span<u8>) {
        self.code = code;
        if code.is_empty() {
            self.code_hash = EMPTY_KECCAK;
            return;
        }
        let hash = code.compute_keccak256_hash();
        self.code_hash = hash;
    }

    /// Registers an account for SELFDESTRUCT
    /// This will cause the account to be erased at the end of the transaction
    #[inline(always)]
    fn selfdestruct(ref self: Account) {
        self.selfdestruct = true;
    }

    /// Returns whether the account is registered for SELFDESTRUCT
    /// `true` means that the account will be erased at the end of the transaction
    #[inline(always)]
    fn is_selfdestruct(self: @Account) -> bool {
        *self.selfdestruct
    }

    /// Initializes a dictionary of valid jump destinations in EVM bytecode.
    ///
    /// This function iterates over the bytecode from the current index 'i'.
    /// If the opcode at the current index is between 0x5f and 0x7f (PUSHN opcodes) (inclusive),
    /// it skips the next 'n_args' opcodes, where 'n_args' is the opcode minus 0x5f.
    /// If the opcode is 0x5b (JUMPDEST), it marks the current index as a valid jump destination.
    /// It continues by jumping back to the body flag until it has processed the entire bytecode.
    ///
    /// # Arguments
    /// * `bytecode` The bytecode to analyze
    ///
    /// # Returns
    /// A dictionary of valid jump destinations in the bytecode
    fn get_jumpdests(mut bytecode: Span<u8>) -> Felt252Dict<bool> {
        let mut jumpdests: Felt252Dict<bool> = Default::default();
        let mut i: usize = 0;
        while i < bytecode.len() {
            let opcode = *bytecode[i];
            // checking for PUSH opcode family
            if opcode >= 0x5f && opcode <= 0x7f {
                let n_args = opcode.into() - 0x5f;
                i += n_args + 1;
                continue;
            }

            if opcode == 0x5b {
                jumpdests.insert(i.into(), true);
            }

            i += 1;
        }
        jumpdests
    }
}

#[cfg(test)]
mod tests {
    mod test_has_code_or_nonce {
        use crate::eth_call::evm::model::account::{Account, AccountTrait};
        use crate::eth_call::utils::constants::EMPTY_KECCAK;
        use crate::eth_call::utils::traits::bytes::U8SpanExTrait;

        #[test]
        fn test_should_return_false_when_empty() {
            let account = Account {
                address: 1.try_into().unwrap(),
                nonce: 0,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(!account.has_code_or_nonce());
        }

        #[test]
        fn test_should_return_true_when_code() {
            let bytecode = [0x5b].span();
            let code_hash = bytecode.compute_keccak256_hash();
            let account = Account {
                address: 1.try_into().unwrap(),
                nonce: 1,
                code: bytecode,
                code_hash: code_hash,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(account.has_code_or_nonce());
        }

        #[test]
        fn test_should_return_true_when_nonce() {
            let account = Account {
                address: 1.try_into().unwrap(),
                nonce: 1,
                code: [].span(),
                code_hash: EMPTY_KECCAK,
                balance: 0,
                selfdestruct: false,
                is_created: false,
            };

            assert!(account.has_code_or_nonce());
        }
    }
}
