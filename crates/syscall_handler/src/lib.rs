#![allow(async_fn_in_trait)]
#![feature(trait_alias)]
#![forbid(unsafe_code)]
#![warn(unused_crate_dependencies)]
#![warn(unused_extern_crates)]

pub mod call_contract;
pub mod keccak;
pub mod traits;

use std::{fmt::Debug, rc::Rc};

use ::serde::{Deserialize, Serialize};
use cairo_vm::{
    types::{
        errors::math_errors::MathError,
        relocatable::{MaybeRelocatable, Relocatable},
    },
    vm::{
        errors::{hint_errors::HintError, memory_errors::MemoryError, vm_errors::VirtualMachineError},
        vm_core::VirtualMachine,
    },
    Felt252,
};
use call_contract::{arbitrary_type::ArbitraryTypeCallContractHandler, debug::DebugCallContractHandler};
use keccak::KeccakHandler;
use thiserror::Error;
use tokio::{sync::RwLock, task};
use traits::CallContractSyscallHandler;
use types::{
    cairo::{
        new_syscalls::{CallContractRequest, CallContractResponse},
        traits::CairoType,
    },
    ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
};

pub const INJECTED_STATE_CONTRACT_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x696e6a65637465645f7374617465"); // 'injected_state' in hex

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum SyscallSelector {
    CallContract,
    Keccak,
}

impl TryFrom<Felt252> for SyscallSelector {
    type Error = HintError;
    fn try_from(raw_selector: Felt252) -> Result<Self, Self::Error> {
        // Remove leading zero bytes from selector.
        let selector_bytes = raw_selector.to_bytes_be();
        let first_non_zero = selector_bytes.iter().position(|&byte| byte != b'\0').unwrap_or(32);

        match &selector_bytes[first_non_zero..] {
            b"CallContract" => Ok(Self::CallContract),
            b"Keccak" => Ok(Self::Keccak),
            _ => Err(HintError::CustomHint(format!("Unknown syscall selector: {}", raw_selector).into())),
        }
    }
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct SyscallHandler<EVM: CallContractSyscallHandler, STARKNET: CallContractSyscallHandler, InjectedState: CallContractSyscallHandler>
{
    #[serde(skip)]
    pub syscall_ptr: Option<Relocatable>,
    pub call_contract_handler: CallContractHandlerRelay<EVM, STARKNET, InjectedState>,
    #[serde(skip)]
    pub keccak_handler: KeccakHandler,
}

impl<
        EVM: Default + CallContractSyscallHandler,
        STARKNET: Default + CallContractSyscallHandler,
        InjectedState: Default + CallContractSyscallHandler,
    > SyscallHandler<EVM, STARKNET, InjectedState>
{
    pub fn new(
        evm_call_contract_handler: EVM,
        starknet_call_contract_handler: STARKNET,
        injected_state_call_contract_handler: InjectedState,
    ) -> Self {
        Self {
            syscall_ptr: Option::default(),
            call_contract_handler: CallContractHandlerRelay::new(
                evm_call_contract_handler,
                starknet_call_contract_handler,
                injected_state_call_contract_handler,
            ),
            keccak_handler: KeccakHandler::default(),
        }
    }
}

/// SyscallHandler is wrapped in Rc<RefCell<_>> in order
/// to clone the reference when entering and exiting vm scopes
#[derive(Debug, Default, Clone)]
pub struct SyscallHandlerWrapper<
    EVM: CallContractSyscallHandler,
    STARKNET: CallContractSyscallHandler,
    InjectedState: CallContractSyscallHandler,
> {
    pub syscall_handler: Rc<RwLock<SyscallHandler<EVM, STARKNET, InjectedState>>>,
}

impl<
        EVM: Default + CallContractSyscallHandler,
        STARKNET: Default + CallContractSyscallHandler,
        InjectedState: Default + CallContractSyscallHandler,
    > SyscallHandlerWrapper<EVM, STARKNET, InjectedState>
{
    pub fn new(
        evm_call_contract_handler: EVM,
        starknet_call_contract_handler: STARKNET,
        injected_state_call_contract_handler: InjectedState,
    ) -> Self {
        Self {
            syscall_handler: Rc::new(RwLock::new(SyscallHandler::new(
                evm_call_contract_handler,
                starknet_call_contract_handler,
                injected_state_call_contract_handler,
            ))),
        }
    }
    pub fn set_syscall_ptr(&self, syscall_ptr: Relocatable) {
        let mut syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_write());
        syscall_handler.syscall_ptr = Some(syscall_ptr);
    }

    pub fn syscall_ptr(&self) -> Option<Relocatable> {
        let syscall_handler = task::block_in_place(|| self.syscall_handler.blocking_read());
        syscall_handler.syscall_ptr
    }

    pub async fn execute_syscall(&mut self, vm: &mut VirtualMachine, syscall_ptr: Relocatable) -> Result<(), HintError> {
        let mut syscall_handler = self.syscall_handler.write().await;
        let ptr = &mut syscall_handler
            .syscall_ptr
            .ok_or(HintError::CustomHint(Box::from("syscall_ptr is None")))?;

        assert_eq!(*ptr, syscall_ptr);

        match SyscallSelector::try_from(felt_from_ptr(vm, ptr)?)? {
            SyscallSelector::CallContract => run_handler(&mut syscall_handler.call_contract_handler, ptr, vm).await,
            SyscallSelector::Keccak => run_handler(&mut syscall_handler.keccak_handler, ptr, vm).await,
        }?;

        syscall_handler.syscall_ptr = Some(*ptr);

        Ok(())
    }
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct CallContractHandlerRelay<
    EVM: CallContractSyscallHandler,
    STARKNET: CallContractSyscallHandler,
    InjectedState: CallContractSyscallHandler,
> {
    // #[serde(bound(serialize = "EVM: Serialize", deserialize = "EVM: Deserialize<'de>"))]
    pub evm_call_contract_handler: EVM,
    #[serde(bound(serialize = "STARKNET: Serialize", deserialize = "STARKNET: Deserialize<'de>"))]
    pub starknet_call_contract_handler: STARKNET,
    #[serde(skip)]
    pub debug_call_contract_handler: DebugCallContractHandler,
    #[serde(skip)]
    pub any_type_call_contract_handler: ArbitraryTypeCallContractHandler,
    #[serde(bound(serialize = "InjectedState: Serialize", deserialize = "InjectedState: Deserialize<'de>"))]
    pub injected_state_call_contract_handler: InjectedState,
}

impl<EVM: CallContractSyscallHandler, STARKNET: CallContractSyscallHandler, InjectedState: CallContractSyscallHandler>
    CallContractHandlerRelay<EVM, STARKNET, InjectedState>
{
    pub fn new(
        evm_call_contract_handler: EVM,
        starknet_call_contract_handler: STARKNET,
        injected_state_call_contract_handler: InjectedState,
    ) -> Self {
        Self {
            evm_call_contract_handler,
            starknet_call_contract_handler,
            injected_state_call_contract_handler,
            debug_call_contract_handler: DebugCallContractHandler,
            any_type_call_contract_handler: ArbitraryTypeCallContractHandler,
        }
    }
}

impl<EVM: CallContractSyscallHandler, STARKNET: CallContractSyscallHandler, InjectedState: CallContractSyscallHandler>
    traits::SyscallHandler for CallContractHandlerRelay<EVM, STARKNET, InjectedState>
{
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        match request.contract_address {
            v if v == call_contract::debug::CONTRACT_ADDRESS => self.debug_call_contract_handler.execute(request, vm).await,
            v if v == call_contract::arbitrary_type::CONTRACT_ADDRESS => self.any_type_call_contract_handler.execute(request, vm).await,
            v if v == INJECTED_STATE_CONTRACT_ADDRESS => self.injected_state_call_contract_handler.execute(request, vm).await,
            _ => {
                let chain_id = <Felt252 as TryInto<u128>>::try_into(*vm.get_integer((request.calldata_start + 2)?)?)
                    .map_err(|e| SyscallExecutionError::InternalError(e.to_string().into()))?;

                match chain_id {
                    ETHEREUM_MAINNET_CHAIN_ID | ETHEREUM_TESTNET_CHAIN_ID => self.evm_call_contract_handler.execute(request, vm).await,
                    STARKNET_MAINNET_CHAIN_ID | STARKNET_TESTNET_CHAIN_ID => self.starknet_call_contract_handler.execute(request, vm).await,
                    _ => Err(SyscallExecutionError::InternalError(Box::from("Unknown chain id"))),
                }
            }
        }
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}

pub fn felt_from_ptr(vm: &VirtualMachine, ptr: &mut Relocatable) -> Result<Felt252, MemoryError> {
    let felt = vm.get_integer(*ptr)?.into_owned();
    *ptr = (*ptr + 1)?;
    Ok(felt)
}

pub fn ignore_felt(ptr: &mut Relocatable) -> SyscallResult<()> {
    *ptr = (*ptr + 1)?;
    Ok(())
}

pub fn read_felt_array<TErr>(vm: &VirtualMachine, ptr: &mut Relocatable) -> Result<Vec<Felt252>, TErr>
where
    TErr: From<VirtualMachineError> + From<MemoryError> + From<MathError>,
{
    let array_data_start_ptr = vm.get_relocatable(*ptr)?;
    *ptr = (*ptr + 1)?;
    let array_data_end_ptr = vm.get_relocatable(*ptr)?;
    *ptr = (*ptr + 1)?;
    let array_size = (array_data_end_ptr - array_data_start_ptr)?;

    let values = vm.get_integer_range(array_data_start_ptr, array_size)?;

    Ok(values.into_iter().map(|felt| felt.into_owned()).collect())
}

pub fn ignore_felt_array(ptr: &mut Relocatable) -> SyscallResult<()> {
    // skip data start and end pointers, see `read_felt_array` function above.
    *ptr = (*ptr + 2)?;
    Ok(())
}

pub fn read_calldata(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Vec<Felt252>> {
    read_felt_array::<SyscallExecutionError>(vm, ptr)
}

pub fn read_call_params(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<(Felt252, Vec<Felt252>)> {
    let function_selector = felt_from_ptr(vm, ptr)?;
    let calldata = read_calldata(vm, ptr)?;

    Ok((function_selector, calldata))
}

pub fn write_felt(vm: &mut VirtualMachine, ptr: &mut Relocatable, felt: Felt252) -> Result<(), MemoryError> {
    write_maybe_relocatable(vm, ptr, felt)
}

pub fn write_maybe_relocatable<T: Into<MaybeRelocatable>>(
    vm: &mut VirtualMachine,
    ptr: &mut Relocatable,
    value: T,
) -> Result<(), MemoryError> {
    vm.insert_value(*ptr, value.into())?;
    *ptr = (*ptr + 1)?;
    Ok(())
}

#[derive(Debug, Error)]
pub enum SyscallExecutionError {
    #[error("Internal Error: {0}")]
    InternalError(Box<str>),
    #[error("Invalid address domain: {address_domain:?}")]
    InvalidAddressDomain { address_domain: Felt252 },
    #[error("Invalid syscall input: {input:?}; {info}")]
    InvalidSyscallInput { input: Felt252, info: String },
    #[error("Syscall error.")]
    SyscallError { error_data: Vec<Felt252> },
}

impl From<MemoryError> for SyscallExecutionError {
    fn from(error: MemoryError) -> Self {
        Self::InternalError(format!("Memory error: {}", error).into())
    }
}

impl From<SyscallExecutionError> for HintError {
    fn from(error: SyscallExecutionError) -> Self {
        HintError::CustomHint(format!("SyscallExecution error: {}", error).into())
    }
}

impl From<HintError> for SyscallExecutionError {
    fn from(error: HintError) -> Self {
        Self::InternalError(format!("Hint error: {}", error).into())
    }
}

impl From<VirtualMachineError> for SyscallExecutionError {
    fn from(error: VirtualMachineError) -> Self {
        Self::InternalError(format!("VirtualMachine error: {}", error).into())
    }
}

impl From<MathError> for SyscallExecutionError {
    fn from(error: MathError) -> Self {
        Self::InternalError(format!("MathError error: {}", error).into())
    }
}

pub type SyscallResult<T> = Result<T, SyscallExecutionError>;
pub type WriteResponseResult = SyscallResult<()>;

fn write_failure(gas_counter: Felt252, error_data: Vec<Felt252>, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<()> {
    write_felt(vm, ptr, gas_counter)?;
    // 1 to indicate failure.
    write_felt(vm, ptr, Felt252::ONE)?;

    // Write the error data to a new memory segment.
    let revert_reason_start = vm.add_memory_segment();
    let revert_reason_end = vm.load_data(revert_reason_start, &error_data.into_iter().map(Into::into).collect::<Vec<_>>())?;

    // Write the start and end pointers of the error data.
    write_maybe_relocatable(vm, ptr, revert_reason_start)?;
    write_maybe_relocatable(vm, ptr, revert_reason_end)?;

    Ok(())
}

pub async fn run_handler(
    syscall_handler: &mut impl traits::SyscallHandler,
    syscall_ptr: &mut Relocatable,
    vm: &mut VirtualMachine,
) -> Result<(), HintError> {
    let remaining_gas = felt_from_ptr(vm, syscall_ptr)?;
    let request = syscall_handler.read_request(vm, syscall_ptr)?;
    let syscall_result = syscall_handler.execute(request, vm).await;
    match syscall_result {
        Ok(response) => {
            write_felt(vm, syscall_ptr, remaining_gas)?;
            write_felt(vm, syscall_ptr, Felt252::ZERO)?;
            syscall_handler.write_response(response, vm, syscall_ptr)?
        }
        Err(SyscallExecutionError::SyscallError { error_data: data }) => {
            write_failure(Felt252::ZERO, data, vm, syscall_ptr)?;
        }
        Err(error) => return Err(error.into()),
    };

    Ok(())
}
