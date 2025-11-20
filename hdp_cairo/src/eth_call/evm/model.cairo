pub mod account;
pub mod vm;
use account::AccountTrait;
use core::num::traits::{CheckedSub, Zero};
use hdp_cairo::HDP;
use starknet::EthAddress;
pub use vm::{VM, VMTrait};
use crate::eth_call::evm::errors::EVMError;
use crate::eth_call::evm::memory::materialize_span_to_array;
use crate::eth_call::evm::precompiles::{
    FIRST_ETHEREUM_PRECOMPILE_ADDRESS, FIRST_ROLLUP_PRECOMPILE_ADDRESS,
    LAST_ETHEREUM_PRECOMPILE_ADDRESS,
};
use crate::eth_call::evm::state::State;
pub use crate::eth_call::hdp_backend::is_deployed;
use crate::eth_call::hdp_backend::{
    TimeAndSpace, fetch_base_fee, fetch_coinbase, fetch_gas_limit, fetch_number, fetch_prevrandao,
    fetch_timestamp,
};
use crate::eth_call::utils::fmt::TSpanSetDebug;
use crate::eth_call::utils::set::SpanSet;
use crate::eth_call::utils::traits::{ContractAddressDefault, EthAddressDefault, SpanDefault};

/// Represents the execution environment for EVM transactions.
#[derive(Destruct, Default)]
pub struct Environment {
    /// The origin address of the transaction.
    pub origin: EthAddress,
    /// The gas price for the transaction.
    pub gas_price: u128,
    /// The chain ID of the network.
    pub chain_id: u64,
    /// The current block number.
    pub block_number: u64,
    /// The previous RANDAO value.
    prevrandao: Option<u256>,
    /// The gas limit for the current block.
    block_gas_limit: Option<u64>,
    /// The timestamp of the current block.
    block_timestamp: Option<u64>,
    /// The address of the coinbase.
    coinbase: Option<EthAddress>,
    /// The base fee for the current block.
    base_fee: Option<u64>,
    /// The state of the EVM.
    pub state: State,
    pub hdp: Option<@HDP>,
}

#[generate_trait]
pub impl EnvironmentImpl of EnvironmentTrait {
    fn new(
        origin: EthAddress,
        gas_price: u128,
        state: State,
        hdp: Option<@HDP>,
        time_and_space: @TimeAndSpace,
    ) -> Environment {
        Environment {
            origin,
            gas_price,
            state,
            hdp,
            chain_id: (*time_and_space.chain_id).try_into().unwrap(),
            block_number: (*time_and_space.block_number).try_into().unwrap(),
            prevrandao: None,
            block_gas_limit: None,
            block_timestamp: None,
            coinbase: None,
            base_fee: None,
        }
    }

    fn get_prevrandao(ref self: Environment) -> u256 {
        if let Some(prevrandao) = self.prevrandao {
            return prevrandao;
        }
        let time_and_space = TimeAndSpace {
            chain_id: self.chain_id.into(), block_number: self.block_number.into(),
        };
        self.prevrandao = Some(fetch_prevrandao(self.hdp, @time_and_space));
        self.prevrandao.unwrap()
    }

    fn get_block_gas_limit(ref self: Environment) -> u64 {
        if let Some(block_gas_limit) = self.block_gas_limit {
            return block_gas_limit;
        }
        let time_and_space = TimeAndSpace {
            chain_id: self.chain_id.into(), block_number: self.block_number.into(),
        };
        self.block_gas_limit = Some(fetch_gas_limit(self.hdp, @time_and_space));
        self.block_gas_limit.unwrap()
    }

    fn get_block_timestamp(ref self: Environment) -> u64 {
        if let Some(block_timestamp) = self.block_timestamp {
            return block_timestamp;
        }
        let time_and_space = TimeAndSpace {
            chain_id: self.chain_id.into(), block_number: self.block_number.into(),
        };
        self.block_timestamp = Some(fetch_timestamp(self.hdp, @time_and_space));
        self.block_timestamp.unwrap()
    }

    fn get_coinbase(ref self: Environment) -> EthAddress {
        if let Some(coinbase) = self.coinbase {
            return coinbase;
        }
        let time_and_space = TimeAndSpace {
            chain_id: self.chain_id.into(), block_number: self.block_number.into(),
        };
        self.coinbase = Some(fetch_coinbase(self.hdp, @time_and_space));
        self.coinbase.unwrap()
    }


    fn get_base_fee(ref self: Environment) -> u64 {
        if let Some(base_fee) = self.base_fee {
            return base_fee;
        }
        let time_and_space = TimeAndSpace {
            chain_id: self.chain_id.into(), block_number: self.block_number.into(),
        };
        self.base_fee = Some(fetch_base_fee(self.hdp, @time_and_space));
        self.base_fee.unwrap()
    }
}

/// Represents a message call in the EVM.
#[derive(Copy, Drop, Default, PartialEq, Debug)]
pub struct Message {
    /// The address of the caller.
    pub caller: EthAddress,
    /// The target address of the call.
    pub target: EthAddress,
    /// The gas limit for the call.
    pub gas_limit: u64,
    /// The data passed to the call.
    pub data: Span<u8>,
    /// The code of the contract being called.
    pub code: Span<u8>,
    /// The address of the code being executed.
    pub code_address: EthAddress,
    /// The value sent with the call.
    pub value: u256,
    /// Whether the value should be transferred.
    pub should_transfer_value: bool,
    /// The depth of the call stack.
    pub depth: usize,
    /// Whether the call is read-only.
    pub read_only: bool,
    /// Set of accessed addresses during execution.
    pub accessed_addresses: SpanSet<EthAddress>,
    /// Set of accessed storage keys during execution.
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
}

/// Represents the result of an EVM execution.
#[derive(Drop, Debug)]
pub struct ExecutionResult {
    /// The status of the execution result.
    pub status: ExecutionResultStatus,
    /// The return data of the execution.
    pub return_data: Array<u8>,
    /// The remaining gas after execution.
    pub gas_left: u64,
    /// Set of accessed addresses during execution.
    pub accessed_addresses: SpanSet<EthAddress>,
    /// Set of accessed storage keys during execution.
    pub accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    /// The amount of gas refunded during execution.
    pub gas_refund: u64,
}

/// Represents the status of an EVM execution result.
#[derive(Copy, Drop, PartialEq, Debug)]
pub enum ExecutionResultStatus {
    /// The execution was successful.
    Success,
    /// The execution was reverted.
    Revert,
    /// An exception occurred during execution.
    Exception,
}

#[generate_trait]
pub impl ExecutionResultImpl of ExecutionResultTrait {
    /// Creates an `ExecutionResult` for an exceptional failure.
    ///
    /// # Arguments
    ///
    /// * `error` - The error message as a span of bytes.
    /// * `accessed_addresses` - Set of accessed addresses during execution.
    /// * `accessed_storage_keys` - Set of accessed storage keys during execution.
    ///
    /// # Returns
    ///
    /// An `ExecutionResult` with the Exception status and provided data.
    fn exceptional_failure(
        error: Span<u8>,
        accessed_addresses: SpanSet<EthAddress>,
        accessed_storage_keys: SpanSet<(EthAddress, u256)>,
    ) -> ExecutionResult {
        // Materialize the error span into an Array to own the data
        let error_array = materialize_span_to_array(error);
        ExecutionResult {
            status: ExecutionResultStatus::Exception,
            return_data: error_array,
            gas_left: 0,
            accessed_addresses,
            accessed_storage_keys,
            gas_refund: 0,
        }
    }

    /// Decrements the gas_left field of the current execution context by the value amount.
    ///
    /// # Arguments
    ///
    /// * `value` - The amount of gas to charge.
    ///
    /// # Returns
    ///
    /// `Ok(())` if successful, or `Err(EVMError::OutOfGas)` if there's not enough gas.
    #[inline(always)]
    fn charge_gas(ref self: ExecutionResult, value: u64) -> Result<(), EVMError> {
        self.gas_left = self.gas_left.checked_sub(value).ok_or(EVMError::OutOfGas)?;
        Result::Ok(())
    }

    /// Checks if the execution result status is Success.
    ///
    /// # Returns
    ///
    /// `true` if the status is Success, `false` otherwise.
    fn is_success(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Success
    }

    /// Checks if the execution result status is Exception.
    ///
    /// # Returns
    ///
    /// `true` if the status is Exception, `false` otherwise.
    fn is_exception(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Exception
    }

    /// Checks if the execution result status is Revert.
    ///
    /// # Returns
    ///
    /// `true` if the status is Revert, `false` otherwise.
    fn is_revert(self: @ExecutionResult) -> bool {
        *self.status == ExecutionResultStatus::Revert
    }
}

/// Represents a summary of an EVM execution.
#[derive(Destruct)]
pub struct ExecutionSummary {
    /// The status of the execution result.
    pub status: ExecutionResultStatus,
    /// The return data of the execution.
    pub return_data: Span<u8>,
    /// The remaining gas after execution.
    pub gas_left: u64,
    /// The state of the EVM after execution.
    pub state: State,
    /// The amount of gas refunded during execution.
    pub gas_refund: u64,
}

/// Represents the result of an EVM transaction.
#[derive(Destruct)]
pub struct TransactionResult {
    /// Whether the transaction was successful.
    pub success: bool,
    /// The return data of the transaction.
    pub return_data: Span<u8>,
    /// The amount of gas used by the transaction.
    pub gas_used: u64,
    /// The state of the EVM after the transaction.
    pub state: State,
}

#[generate_trait]
pub impl TransactionResultImpl of TransactionResultTrait {
    /// Creates a `TransactionResult` for an exceptional failure.
    ///
    /// # Arguments
    ///
    /// * `error` - The error message as a span of bytes.
    /// * `gas_used` - The amount of gas used during the transaction.
    ///
    /// # Returns
    ///
    /// A `TransactionResult` with failure status and provided data.
    fn exceptional_failure(error: Span<u8>, gas_used: u64) -> TransactionResult {
        TransactionResult {
            success: false, return_data: error, gas_used, state: Default::default(),
        }
    }
}

/// Represents an EVM event.
#[derive(Drop, Clone, Default, PartialEq)]
pub struct Event {
    /// The keys of the event.
    pub keys: Array<u256>,
    /// The data of the event.
    pub data: Array<u8>,
}

#[generate_trait]
pub impl AddressImpl of AddressTrait {
    /// Checks if the EVM address is deployed.
    ///
    /// # Returns
    ///
    /// `true` if the address is deployed, `false` otherwise.
    fn is_deployed(self: @EthAddress, hdp: Option<@HDP>, time_and_space: @TimeAndSpace) -> bool {
        is_deployed(hdp, time_and_space, self)
    }

    /// Checks if the address is a precompile for a call-family opcode.
    ///
    /// # Returns
    ///
    /// `true` if the address is a precompile, `false` otherwise.
    fn is_precompile(self: EthAddress) -> bool {
        let self: felt252 = self.into();
        return self != 0x00
            && (FIRST_ETHEREUM_PRECOMPILE_ADDRESS <= self.into()
                && self.into() <= LAST_ETHEREUM_PRECOMPILE_ADDRESS)
                || self.into() == FIRST_ROLLUP_PRECOMPILE_ADDRESS;
    }
}

/// Represents a native token transfer to be made when finalizing a transaction.
#[derive(Copy, Drop, PartialEq, Debug)]
pub struct Transfer {
    /// The sender of the transfer.
    pub sender: EthAddress,
    /// The recipient of the transfer.
    pub recipient: EthAddress,
    /// The amount of tokens to transfer.
    pub amount: u256,
}
