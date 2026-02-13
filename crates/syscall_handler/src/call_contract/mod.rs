pub mod arbitrary_type;
pub mod debug;
pub mod injected_state;
pub mod unconstrained_state;

use cairo_vm::Felt252;
use strum_macros::FromRepr;

use crate::SyscallExecutionError;

macro_rules! impl_call_handler_try_from {
    ($type:ty) => {
        impl TryFrom<Felt252> for $type {
            type Error = SyscallExecutionError;

            fn try_from(value: Felt252) -> Result<Self, Self::Error> {
                let id = usize::try_from(value).map_err(|e| SyscallExecutionError::InvalidSyscallInput {
                    input: value,
                    info: e.to_string(),
                })?;
                Self::from_repr(id).ok_or(SyscallExecutionError::InvalidSyscallInput {
                    input: value,
                    info: "Invalid function identifier".to_string(),
                })
            }
        }
    };
}

/// Call handler identifiers for EVM operations.
#[derive(Debug, Clone, Copy, FromRepr, PartialEq, Eq)]
pub enum EvmCallHandlerId {
    Header = 0,
    Account = 1,
    Storage = 2,
    Transaction = 3,
    Receipt = 4,
    Log = 5,
}

impl_call_handler_try_from!(EvmCallHandlerId);

/// Call handler identifiers for Starknet operations.
#[derive(Debug, Clone, Copy, FromRepr, PartialEq, Eq)]
pub enum StarknetCallHandlerId {
    Header = 0,
    Storage = 1,
}

impl_call_handler_try_from!(StarknetCallHandlerId);

/// Call handler identifiers for injected state operations.
#[derive(Debug, Clone, Copy, FromRepr, PartialEq, Eq)]
pub enum InjectedStateCallHandlerId {
    Label = 0,
    Read = 1,
    Write = 2,
}

impl_call_handler_try_from!(InjectedStateCallHandlerId);

/// Call handler identifiers for unconstrained operations.
#[derive(Debug, Clone, Copy, FromRepr, PartialEq, Eq)]
pub enum UnconstrainedCallHandlerId {
    Bytecode = 0,
}

impl_call_handler_try_from!(UnconstrainedCallHandlerId);
