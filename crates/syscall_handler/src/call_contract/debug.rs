use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use types::cairo::new_syscalls::{CallContractRequest, CallContractResponse};

use crate::{traits, SyscallExecutionError, SyscallResult, WriteResponseResult};

pub const CONTRACT_ADDRESS: Felt252 = Felt252::from_hex_unchecked("0x6465627567"); // 'debug' in hex

#[derive(FromRepr)]
pub enum CallHandlerId {
    Print = 0,
    PrintArray = 1,
}

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct DebugCallContractHandler;

impl traits::SyscallHandler for DebugCallContractHandler {
    type Request = CallContractRequest;
    type Response = CallContractResponse;

    fn read_request(&mut self, _vm: &VirtualMachine, _ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        unreachable!()
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let call_handler_id = CallHandlerId::try_from(request.selector)?;
        match call_handler_id {
            CallHandlerId::Print => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| *f.as_ref())
                    .collect::<Vec<Felt252>>();

                let str = decode_byte_array_felts(fields);
                println!("{}", str);
                Ok(Self::Response {
                    retdata_start: request.calldata_end,
                    retdata_end: request.calldata_end,
                })
            }
            CallHandlerId::PrintArray => {
                let field_len = (request.calldata_end - request.calldata_start)?;
                let fields = vm
                    .get_integer_range(request.calldata_start, field_len)?
                    .into_iter()
                    .map(|f| *f.as_ref())
                    .collect::<Vec<Felt252>>();

                println!("{:?}", fields);

                Ok(Self::Response {
                    retdata_start: request.calldata_end,
                    retdata_end: request.calldata_end,
                })
            }
        }
    }

    fn write_response(&mut self, _response: Self::Response, _vm: &mut VirtualMachine, _ptr: &mut Relocatable) -> WriteResponseResult {
        unreachable!()
    }
}

// Decodes a serialized byte array of felts into a ascii string
pub fn decode_byte_array_felts(felts: Vec<Felt252>) -> String {
    // 1) Parse how many full 31-byte chunks we have.
    let n_full: usize = felts[0].try_into().expect("n_full not convertible");

    // 2) Read each 31-byte chunk in big-endian order.
    let mut bytes = Vec::new();
    for i in 0..n_full {
        let chunk = &felts[1 + i];
        let chunk_be: Vec<u8> = chunk.to_bytes_be().to_vec();

        // Convert if chain to match
        match chunk_be.len().cmp(&31) {
            std::cmp::Ordering::Less => {
                // Prepend leading zeros if needed
                let mut padded = vec![0u8; 31 - chunk_be.len()];
                padded.extend_from_slice(&chunk_be);
                bytes.extend_from_slice(&padded);
            }
            std::cmp::Ordering::Greater => {
                // If somehow bigger, take the last 31 bytes
                bytes.extend_from_slice(&chunk_be[chunk_be.len() - 31..]);
            }
            std::cmp::Ordering::Equal => {
                bytes.extend_from_slice(&chunk_be);
            }
        }
    }

    // 3) The next felt is the pending word, followed by the pending length.
    let pending_word = &felts[1 + n_full];
    let pending_len: usize = felts[1 + n_full + 1].try_into().unwrap();

    if pending_len > 0 {
        let pending_be: Vec<u8> = pending_word.to_bytes_be().to_vec();
        // Convert if chain to match
        match pending_be.len().cmp(&pending_len) {
            std::cmp::Ordering::Less => {
                // Again pad if needed
                let mut padded = vec![0u8; pending_len - pending_be.len()];
                padded.extend_from_slice(&pending_be);
                bytes.extend_from_slice(&padded);
            }
            std::cmp::Ordering::Greater => {
                bytes.extend_from_slice(&pending_be[pending_be.len() - pending_len..]);
            }
            std::cmp::Ordering::Equal => {
                bytes.extend_from_slice(&pending_be);
            }
        }
    }

    // 4) Convert raw bytes to a UTF-8 string (or ASCII if you know it is ASCII).
    String::from_utf8(bytes).expect("Invalid UTF-8")
}

impl TryFrom<Felt252> for CallHandlerId {
    type Error = SyscallExecutionError;
    fn try_from(value: Felt252) -> Result<Self, Self::Error> {
        Self::from_repr(value.try_into().map_err(|e| Self::Error::InvalidSyscallInput {
            input: value,
            info: format!("{}", e),
        })?)
        .ok_or(Self::Error::InvalidSyscallInput {
            input: value,
            info: "Invalid function identifier".to_string(),
        })
    }
}
