use cairo_vm::{
    types::{
        errors::math_errors::MathError,
        relocatable::{MaybeRelocatable, Relocatable},
    },
    vm::{
        errors::{
            hint_errors::HintError, memory_errors::MemoryError, vm_errors::VirtualMachineError,
        },
        vm_core::VirtualMachine,
    },
    Felt252,
};
use thiserror::Error;

#[derive(Clone, Copy, Debug, Eq, Hash, PartialEq)]
pub enum SyscallSelector {
    CallContract,
}

impl TryFrom<Felt252> for SyscallSelector {
    type Error = HintError;
    fn try_from(raw_selector: Felt252) -> Result<Self, Self::Error> {
        // Remove leading zero bytes from selector.
        let selector_bytes = raw_selector.to_bytes_be();
        let first_non_zero = selector_bytes
            .iter()
            .position(|&byte| byte != b'\0')
            .unwrap_or(32);

        match &selector_bytes[first_non_zero..] {
            b"CallContract" => Ok(Self::CallContract),
            _ => Err(HintError::CustomHint(
                format!("Unknown syscall selector: {}", raw_selector).into(),
            )),
        }
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

pub fn read_felt_array<TErr>(
    vm: &VirtualMachine,
    ptr: &mut Relocatable,
) -> Result<Vec<Felt252>, TErr>
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

pub fn read_call_params(
    vm: &VirtualMachine,
    ptr: &mut Relocatable,
) -> SyscallResult<(Felt252, Vec<Felt252>)> {
    let function_selector = felt_from_ptr(vm, ptr)?;
    let calldata = read_calldata(vm, ptr)?;

    Ok((function_selector, calldata))
}

pub fn write_felt(
    vm: &mut VirtualMachine,
    ptr: &mut Relocatable,
    felt: Felt252,
) -> Result<(), MemoryError> {
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

// Common structs.

#[derive(Debug, Eq, PartialEq)]
pub struct EmptyRequest;

#[derive(Debug, Eq, PartialEq)]
pub struct EmptyResponse;

#[derive(Debug)]
// Invariant: read-only.
pub struct ReadOnlySegment {
    pub start_ptr: Relocatable,
    pub length: usize,
}

pub fn write_segment(
    vm: &mut VirtualMachine,
    ptr: &mut Relocatable,
    segment: ReadOnlySegment,
) -> SyscallResult<()> {
    write_maybe_relocatable(vm, ptr, segment.start_ptr)?;
    let segment_end_ptr = (segment.start_ptr + segment.length)?;
    write_maybe_relocatable(vm, ptr, segment_end_ptr)?;

    Ok(())
}

#[allow(async_fn_in_trait)]
pub trait SyscallHandler {
    type Request;
    type Response;
    fn read_request(vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request>;
    async fn execute(
        request: Self::Request,
        vm: &mut VirtualMachine,
    ) -> SyscallResult<Self::Response>;
    fn write_response(
        response: Self::Response,
        vm: &mut VirtualMachine,
        ptr: &mut Relocatable,
    ) -> WriteResponseResult;
}

fn write_failure(
    gas_counter: Felt252,
    error_data: Vec<Felt252>,
    vm: &mut VirtualMachine,
    ptr: &mut Relocatable,
) -> SyscallResult<()> {
    write_felt(vm, ptr, gas_counter)?;
    // 1 to indicate failure.
    write_felt(vm, ptr, Felt252::ONE)?;

    // Write the error data to a new memory segment.
    let revert_reason_start = vm.add_memory_segment();
    let revert_reason_end = vm.load_data(
        revert_reason_start,
        &error_data.into_iter().map(Into::into).collect::<Vec<_>>(),
    )?;

    // Write the start and end pointers of the error data.
    write_maybe_relocatable(vm, ptr, revert_reason_start)?;
    write_maybe_relocatable(vm, ptr, revert_reason_end)?;

    Ok(())
}

// Dummy value we dont use gas in HDP runtime
pub const REMAINING_GAS: Felt252 = Felt252::from_hex_unchecked("0xffffff");
pub const OUT_OF_GAS_ERROR: &str =
    "0x000000000000000000000000000000000000000000004f7574206f6620676173";

pub async fn run_handler<SH>(
    syscall_ptr: &mut Relocatable,
    vm: &mut VirtualMachine,
) -> Result<(), HintError>
where
    SH: SyscallHandler,
{
    let request = SH::read_request(vm, syscall_ptr)?;
    let syscall_result = SH::execute(request, vm).await;
    match syscall_result {
        Ok(response) => {
            write_felt(vm, syscall_ptr, REMAINING_GAS)?;
            // 0 to indicate success.
            write_felt(vm, syscall_ptr, Felt252::ZERO)?;
            SH::write_response(response, vm, syscall_ptr)?
        }
        Err(SyscallExecutionError::SyscallError { error_data: data }) => {
            write_failure(REMAINING_GAS, data, vm, syscall_ptr)?;
        }
        Err(error) => return Err(error.into()),
    };

    Ok(())
}
