use core::dict::{Felt252Dict, Felt252DictTrait};
use core::hash::{HashStateExTrait, HashStateTrait};
use core::nullable::{FromNullableResult, match_nullable};
use core::num::traits::{OverflowingAdd, OverflowingSub};
use core::poseidon::PoseidonTrait;
use hdp_cairo::HDP;
use starknet::EthAddress;
use starknet::storage_access::{StorageBaseAddress, storage_base_address_from_felt252};
use crate::eth_call::evm::errors::{BALANCE_OVERFLOW, EVMError, ensure};
use crate::eth_call::evm::model::account::{Account, AccountTrait};
use crate::eth_call::evm::model::{Event, Transfer};
use crate::eth_call::hdp_backend::{TimeAndSpace, fetch_original_storage};
use crate::eth_call::utils::set::{Set, SetTrait};

/// The `StateChangeLog` tracks the changes applied to storage during the execution of a
/// transaction.
/// Upon exiting an execution context, contextual changes must be finalized into transactional
/// changes.
/// Upon exiting the transaction, transactional changes must be finalized into storage updates.
///
/// # Type Parameters
///
/// * `T` - The type of values stored in the log.
///
/// # Fields
///
/// * `changes` - A `Felt252Dict` of contextual changes. Tracks the changes applied inside a single
/// execution context.
/// * `keyset` - An `Array` of contextual keys.
pub struct StateChangeLog<T> {
    pub changes: Felt252Dict<Nullable<T>>,
    pub keyset: Set<felt252>,
}

impl StateChangeLogDestruct<T, +Drop<T>> of Destruct<StateChangeLog<T>> {
    fn destruct(self: StateChangeLog<T>) nopanic {
        self.changes.squash();
    }
}

impl StateChangeLogDefault<T, +Drop<T>> of Default<StateChangeLog<T>> {
    fn default() -> StateChangeLog<T> {
        StateChangeLog { changes: Default::default(), keyset: Default::default() }
    }
}

#[generate_trait]
impl StateChangeLogImpl<T, +Drop<T>, +Copy<T>> of StateChangeLogTrait<T> {
    /// Reads a value from the StateChangeLog. Starts by looking for the value in the
    /// contextual changes. If the value is not found, looks for it in the
    /// transactional changes.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to a `StateChangeLog` instance.
    /// * `key` - The key of the value to read.
    ///
    /// # Returns
    ///
    /// An `Option` containing the value if it exists, or `None` if it does not.
    #[inline(always)]
    fn read(ref self: StateChangeLog<T>, key: felt252) -> Option<T> {
        match match_nullable(self.changes.get(key)) {
            FromNullableResult::Null => { Option::None },
            FromNullableResult::NotNull(value) => Option::Some(value.unbox()),
        }
    }

    /// Writes a value to the StateChangeLog.
    /// Values written to the StateChangeLog are not written to storage until the StateChangeLog is
    /// totally finalized at the end of the transaction.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to a `StateChangeLog` instance.
    /// * `key` - The key of the value to write.
    /// * `value` - The value to write.
    #[inline(always)]
    fn write(ref self: StateChangeLog<T>, key: felt252, value: T) {
        self.changes.insert(key, NullableTrait::new(value));
        self.keyset.add(key);
    }

    /// Creates a clone of the current StateChangeLog.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `StateChangeLog` instance to clone.
    ///
    /// # Returns
    ///
    /// A new `StateChangeLog` instance with the same contents as the original.
    fn clone(ref self: StateChangeLog<T>) -> StateChangeLog<T> {
        let mut cloned_changes = Default::default();
        let mut keyset_span = self.keyset.to_span();
        while let Option::Some(key) = keyset_span.pop_front() {
            let value = self.changes.get(*key).deref();
            cloned_changes.insert(*key, NullableTrait::new(value));
        }

        StateChangeLog { changes: cloned_changes, keyset: self.keyset.clone() }
    }
}

#[derive(Default, Destruct)]
pub struct State {
    /// Accounts states - without storage and balances, which are handled separately.
    pub accounts: StateChangeLog<Account>,
    /// Account storage states. `EthAddress` indicates the target contract,
    /// `u256` indicates the storage key.
    /// `u256` indicates the value stored.
    /// We have to store the target contract, as we can't derive it from the
    /// hashed address only when finalizing.
    pub accounts_storage: StateChangeLog<(EthAddress, u256, u256)>,
    /// Account states
    /// Pending emitted events
    pub events: Array<Event>,
    /// Pending transfers
    pub transfers: Array<Transfer>,
    /// Account transient storage states. `EthAddress` indicates the target contract,
    /// `u256` indicates the storage key.
    /// `u256` indicates the value stored.
    pub transient_account_storage: StateChangeLog<(EthAddress, u256, u256)>,
}

#[generate_trait]
pub impl StateImpl of StateTrait {
    /// Retrieves an account from the state, creating it if it doesn't exist.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account to retrieve.
    ///
    /// # Returns
    ///
    /// The `Account` associated with the given EVM address.
    fn get_account(
        ref self: State, evm_address: EthAddress, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
    ) -> Account {
        //? This also has to stay, and we only fetch the unaccessed account from HDP, because
        //? someone can spend money within transaction etc? Idk if we need this, TBD.
        let maybe_account = self.accounts.read(evm_address.into());
        match maybe_account {
            Option::Some(acc) => { return acc; },
            Option::None => {
                let account = AccountTrait::fetch(evm_address, hdp, time_and_space)
                    .unwrap_or_else(
                        || panic!("Accessed account does not exist: {:?}", evm_address),
                    );
                self.accounts.write(evm_address.into(), account);
                return account;
            },
        }
    }

    /// Sets an account in the state.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `account` - The `Account` to set.
    #[inline(always)]
    fn set_account(ref self: State, account: Account) {
        let evm_address = account.evm_address();

        self.accounts.write(evm_address.into(), account)
    }

    /// Reads a value from the state for a given EVM address and key.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account.
    /// * `key` - The storage key.
    ///
    /// # Returns
    ///
    /// The value stored at the given address and key.
    #[inline(always)]
    fn read_state(
        ref self: State,
        hdp: Option<@HDP>,
        time_and_space: @TimeAndSpace,
        evm_address: EthAddress,
        key: u256,
    ) -> u256 {
        //? This makes sense, if the key does not exist in our storage in memory it means we need to
        //? get it with HDP, but it can exist because some EVM bytecode can influence the storage.
        let internal_key = compute_storage_key(evm_address, key);
        let maybe_entry = self.accounts_storage.read(internal_key);
        match maybe_entry {
            Option::Some((_, _, value)) => { return value; },
            Option::None => {
                let account = self.get_account(evm_address, hdp, time_and_space);
                return fetch_original_storage(hdp, time_and_space, @account, key);
            },
        }
    }

    /// Writes a value to the state for a given EVM address and key.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account.
    /// * `key` - The storage key.
    /// * `value` - The value to write.
    #[inline(always)]
    fn write_state(ref self: State, evm_address: EthAddress, key: u256, value: u256) {
        let internal_key = compute_storage_key(evm_address, key);
        self.accounts_storage.write(internal_key.into(), (evm_address, key, value));
    }

    /// Adds an event to the state.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `event` - The `Event` to add.
    #[inline(always)]
    fn add_event(ref self: State, event: Event) {
        self.events.append(event)
    }

    /// Adds a transfer to the state and updates account balances.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `transfer` - The `Transfer` to add.
    ///
    /// # Returns
    ///
    /// A `Result` indicating success or an `EVMError` if the transfer fails.
    #[inline(always)]
    fn add_transfer(
        ref self: State, transfer: Transfer, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
    ) -> Result<(), EVMError> {
        if (transfer.amount == 0 || transfer.sender == transfer.recipient) {
            return Result::Ok(());
        }
        let mut sender = self.get_account(transfer.sender, hdp, time_and_space);
        let mut recipient = self.get_account(transfer.recipient, hdp, time_and_space);

        let (new_sender_balance, underflow) = sender.balance().overflowing_sub(transfer.amount);
        ensure(!underflow, EVMError::InsufficientBalance)?;

        let (new_recipient_balance, overflow) = recipient.balance.overflowing_add(transfer.amount);
        ensure(!overflow, EVMError::NumericOperations(BALANCE_OVERFLOW))?;

        sender.set_balance(new_sender_balance);
        recipient.set_balance(new_recipient_balance);

        self.set_account(sender);
        self.set_account(recipient);

        self.transfers.append(transfer);
        Result::Ok(())
    }

    /// Reads a value from transient storage for a given EVM address and key.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account.
    /// * `key` - The storage key.
    ///
    /// # Returns
    ///
    /// The value stored in transient storage at the given address and key.
    #[inline(always)]
    fn read_transient_storage(ref self: State, evm_address: EthAddress, key: u256) -> u256 {
        let internal_key = compute_storage_key(evm_address, key);
        let maybe_entry = self.transient_account_storage.read(internal_key);
        match maybe_entry {
            Option::Some((_, _, value)) => { return value; },
            Option::None => { return 0; },
        }
    }

    /// Writes a value to transient storage for a given EVM address and key.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account.
    /// * `key` - The storage key.
    /// * `value` - The value to write.
    #[inline(always)]
    fn write_transient_storage(ref self: State, evm_address: EthAddress, key: u256, value: u256) {
        let internal_key = compute_storage_key(evm_address, key);
        self.transient_account_storage.write(internal_key.into(), (evm_address, key, value));
    }

    /// Creates a clone of the current State.
    ///
    /// # Arguments
    ///
    /// * `self` - A reference to the `State` instance to clone.
    ///
    /// # Returns
    ///
    /// A new `State` instance with the same contents as the original.
    #[inline(always)]
    fn clone(ref self: State) -> State {
        State {
            accounts: self.accounts.clone(),
            accounts_storage: self.accounts_storage.clone(),
            events: self.events.clone(),
            transfers: self.transfers.clone(),
            transient_account_storage: self.transient_account_storage.clone(),
        }
    }

    /// Checks if an account is both in the global state and non-empty.
    ///
    /// # Arguments
    ///
    /// * `self` - A mutable reference to the `State` instance.
    /// * `evm_address` - The EVM address of the account to check.
    ///
    /// # Returns
    ///
    /// `true` if the account exists and is non-empty, `false` otherwise.
    #[inline(always)]
    fn is_account_alive(
        ref self: State, evm_address: EthAddress, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
    ) -> bool {
        let account = self.get_account(evm_address, hdp, time_and_space);
        return !(account.nonce == 0 && account.code.len() == 0 && account.balance == 0);
    }
}

/// Computes the key for the internal state for a given EVM storage key.
/// The key is computed as follows:
/// 1. Compute the hash of the EVM address and the key(low, high) using Poseidon.
/// 2. Return the hash
#[inline(always)]
pub fn compute_storage_key(evm_address: EthAddress, key: u256) -> felt252 {
    let hash = PoseidonTrait::new().update_with(evm_address).update_with(key).finalize();
    hash
}

/// Computes the storage address for a given EVM storage key.
/// The storage address is computed as follows:
/// 1. Compute the hash of the key (low, high) using Poseidon.
/// 2. Use `storage_base_address_from_felt252` to obtain the starknet storage base address.
/// Note: the storage_base_address_from_felt252 function always works for any felt - and returns the
/// number normalized into the range [0, 2^251 - 256). (x % (2^251 - 256))
/// https://github.com/starkware-libs/cairo/issues/4187
#[inline(always)]
pub fn compute_storage_address(key: u256) -> StorageBaseAddress {
    let hash = PoseidonTrait::new().update_with(key).finalize();
    storage_base_address_from_felt252(hash)
}
