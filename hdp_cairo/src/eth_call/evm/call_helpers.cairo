//! CALL, CALLCODE, DELEGATECALL, STATICCALL opcode helpers
use core::cmp::min;
use starknet::EthAddress;
use crate::eth_call::evm::errors::EVMError;
use crate::eth_call::evm::interpreter::EVMTrait;
use crate::eth_call::evm::memory::MemoryTrait;
use crate::eth_call::evm::model::vm::{VM, VMTrait};
use crate::eth_call::evm::model::{ExecutionResultStatus, Message};
use crate::eth_call::evm::stack::StackTrait;
use crate::eth_call::evm::state::StateTrait;
use crate::eth_call::utils::constants;
use crate::eth_call::utils::set::SetTrait;
use crate::eth_call::utils::traits::{BoolIntoNumeric, U256TryIntoResult};
use super::test_utils::test_address;

/// CallArgs is a subset of CallContext
/// Created in order to simplify setting up the call opcodes
#[derive(Drop, PartialEq)]
pub struct CallArgs {
    caller: EthAddress,
    code_address: EthAddress,
    to: EthAddress,
    gas: u128,
    value: u256,
    calldata: Span<u8>,
    ret_offset: usize,
    ret_size: usize,
    read_only: bool,
    should_transfer: bool,
    max_memory_size: usize,
}

#[derive(Drop)]
pub enum CallType {
    Call,
    DelegateCall,
    CallCode,
    StaticCall,
}

#[generate_trait]
pub impl CallHelpersImpl of CallHelpers {
    /// Initializes and enters into a new sub-context
    /// The Machine will change its `current_ctx` to point to the
    /// newly created sub-context.
    /// Then, the EVM execution loop will start on this new execution context.
    fn generic_call(
        ref self: VM,
        gas: u64,
        value: u256,
        caller: EthAddress,
        to: EthAddress,
        code_address: EthAddress,
        should_transfer_value: bool,
        is_staticcall: bool,
        args_offset: usize,
        args_size: usize,
        ret_offset: usize,
        ret_size: usize,
    ) -> Result<(), EVMError> {
        self.return_data_buf = Default::default();
        self.return_data = [].span();
        if self.message().depth >= constants::STACK_MAX_DEPTH {
            self.gas_left += gas;
            return self.stack.push(0);
        }

        let mut calldata = Default::default();
        self.memory.load_n(args_size, ref calldata, args_offset);

        // We enter the standard flow
        let code_account = self.env.state.get_account(code_address, self.hdp, @self.time_and_space);
        let read_only = is_staticcall || self.message.read_only;

        let to = to;
        let caller = caller;

        let message = Message {
            caller,
            target: to,
            gas_limit: gas,
            data: calldata.span(),
            code: code_account.code,
            code_address: code_account.address,
            value: value,
            should_transfer_value: should_transfer_value,
            depth: self.message().depth + 1,
            read_only: read_only,
            accessed_addresses: self.accessed_addresses.clone().spanset(),
            accessed_storage_keys: self.accessed_storage_keys.clone().spanset(),
        };

        let result = EVMTrait::process_message(
            message, ref self.env, self.hdp, @self.time_and_space,
        );
        self.merge_child(@result);

        match result.status {
            ExecutionResultStatus::Success => {
                // return_data already set in merge_child, no need to set again
                self.stack.push(1)?;
            },
            ExecutionResultStatus::Revert => {
                // return_data already set in merge_child, no need to set again
                self.stack.push(0)?;
            },
            ExecutionResultStatus::Exception => {
                // If the call has halted exceptionnaly,
                // the return_data is emptied, and nothing is stored in memory
                self.return_data_buf = Default::default();
                self.return_data = [].span();
                self.stack.push(0)?;
                return Result::Ok(());
            },
        }

        // Get the min between len(return_data) and call_ctx.ret_size.
        let actual_returndata_len = min(self.return_data_buf.len(), ret_size);

        // Store bytes individually using store_span_safe to avoid relocatable issues
        let return_data_span = self.return_data_buf.span().slice(0, actual_returndata_len);
        self.memory.store_span_safe(return_data_span, ret_offset);
        // TODO: Check if need to pad the memory with zeroes if result.return_data.len() <
        // call_ctx.ret_size and memory is not empty at offset call_args.ret_offset +
        // result.return_data.len()

        Result::Ok(())
    }
}
