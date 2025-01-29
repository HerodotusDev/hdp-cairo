use cairo_vm::{types::relocatable::Relocatable, vm::vm_core::VirtualMachine, Felt252};
use num_bigint::BigUint;
use num_traits::cast::ToPrimitive;
use serde::{Deserialize, Serialize};
use types::cairo::{
    new_syscalls::{KeccakRequest, KeccakResponse},
    traits::CairoType,
};

use crate::{traits::SyscallHandler, SyscallExecutionError, SyscallResult, WriteResponseResult};

pub const KECCAK_FULL_RATE_IN_U64S: usize = 17;
pub const KECCAK_ROUND_COST_GAS_COST: usize = 180000;
pub const INVALID_INPUT_LENGTH_ERROR: &str = "0x000000000000000000000000496e76616c696420696e707574206c656e677468";

#[derive(Debug, Default, Serialize, Deserialize, Clone)]
pub struct KeccakHandler {}

impl SyscallHandler for KeccakHandler {
    type Request = KeccakRequest;
    type Response = KeccakResponse;

    fn read_request(&mut self, vm: &VirtualMachine, ptr: &mut Relocatable) -> SyscallResult<Self::Request> {
        let ret = Self::Request::from_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Request::cairo_size())?;
        Ok(ret)
    }

    async fn execute(&mut self, request: Self::Request, vm: &mut VirtualMachine) -> SyscallResult<Self::Response> {
        let input_len = (request.input_end - request.input_start)?;
        // The to_usize unwrap will not fail as the constant value is 17
        let (_, remainder) = num_integer::div_rem(input_len, KECCAK_FULL_RATE_IN_U64S);

        if remainder != 0 {
            return Err(SyscallExecutionError::SyscallError {
                error_data: vec![Felt252::from_hex_unchecked(INVALID_INPUT_LENGTH_ERROR)],
            });
        }

        let input_felt_array = vm.get_integer_range(request.input_start, input_len)?;

        // Keccak state function consist of 25 words 64 bits each for SHA-3 (200 bytes/1600 bits)
        // Sponge Function [https://en.wikipedia.org/wiki/Sponge_function]
        // SHA3 [https://en.wikipedia.org/wiki/SHA-3]
        let mut state = [0u64; 25];
        for chunk in input_felt_array.chunks(KECCAK_FULL_RATE_IN_U64S) {
            for (i, val) in chunk.iter().enumerate() {
                state[i] ^= val.to_u64().ok_or_else(|| SyscallExecutionError::InvalidSyscallInput {
                    input: *val.clone(),
                    info: String::from("Invalid input for the keccak syscall."),
                })?;
            }
            keccak::f1600(&mut state)
        }
        // We keep 256 bits (128 high and 128 low)
        let result_low = (BigUint::from(state[1]) << 64u32) + BigUint::from(state[0]);
        let result_high = (BigUint::from(state[3]) << 64u32) + BigUint::from(state[2]);

        Ok(KeccakResponse {
            result_low: (Felt252::from(result_low)),
            result_high: (Felt252::from(result_high)),
        })
    }

    fn write_response(&mut self, response: Self::Response, vm: &mut VirtualMachine, ptr: &mut Relocatable) -> WriteResponseResult {
        response.to_memory(vm, *ptr)?;
        *ptr = (*ptr + Self::Response::cairo_size())?;
        Ok(())
    }
}
