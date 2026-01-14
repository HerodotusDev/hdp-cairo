use starknet::syscalls::call_contract_syscall;
use starknet::{ContractAddress, EthAddress};
use core::array::{ArrayTrait, SpanTrait};
use crate::HDP;
use super::hdp_backend::{TimeAndSpace, fetch_timestamp};

/// Result of a Cairo Zero EVM execution
/// This is a simplified struct independent of Cairo 1 EVM State
#[derive(Drop, Debug)]
pub struct EvmCallResult {
    /// Whether the execution was successful
    pub success: bool,
    /// The return data from the execution
    pub return_data: Span<u8>,
    /// The amount of gas used
    pub gas_used: u64,
}

impl EvmCallResultDefault of Default<EvmCallResult> {
    fn default() -> EvmCallResult {
        EvmCallResult { success: false, return_data: [].span(), gas_used: 0 }
    }
}

/// Execute an eth_call using Cairo Zero EVM via syscall
/// 
/// During dry-run: Records dependency keys and returns mock success
/// During sound-run: Executes full EVM via Cairo Zero interpreter
pub fn execute_eth_call_zero(
    hdp: @HDP,
    time_and_space: @TimeAndSpace,
    sender: EthAddress,
    target: EthAddress,
    calldata: Span<u8>,
) -> EvmCallResult {
    // Fetch timestamp from HDP
    let timestamp = fetch_timestamp(Option::Some(hdp), time_and_space);
    
    // Pack arguments into a felt252 array
    let mut call_data = ArrayTrait::new();
    call_data.append((*time_and_space.chain_id).try_into().unwrap());
    call_data.append((*time_and_space.block_number).try_into().unwrap());
    call_data.append(timestamp.into());
    call_data.append(target.into());
    call_data.append(sender.into());
    call_data.append(sender.into()); // origin
    call_data.append(0); // value low
    call_data.append(0); // value high
    call_data.append(50_000_000); // gas_limit
    call_data.append(0); // read_only
    call_data.append(0); // depth
    call_data.append(calldata.len().into());

    // Append calldata bytes
    let mut i = 0;
    while i < calldata.len() {
        call_data.append((*calldata.at(i)).into());
        i += 1;
    }

    // Target contract address for the 'evm_executor' syscall
    let evm_executor_addr = 0x65766d5f6578656375746f72; // 'evm_executor' in felt
    let evm_executor_contract: ContractAddress = evm_executor_addr.try_into().unwrap();

    // Call the syscall with proper error handling
    let result = match call_contract_syscall(evm_executor_contract, 0, call_data.span()) {
        Result::Ok(result) => result,
        Result::Err(_) => {
            // Syscall failed, return default error result
            return EvmCallResultDefault::default();
        }
    };

    // Unpack response
    // Response format: [success, gas_used, return_data_len, ...return_data_bytes]
    // result is a Span<felt252>
    if SpanTrait::len(result) < 3 {
        // Invalid response format (need at least success, gas_used, return_data_len), return error
        return EvmCallResultDefault::default();
    }
    
    let success_felt = *SpanTrait::at(result, 0);
    let success = success_felt == 1;
    
    // Extract gas_used (second element)
    let gas_used_felt = *SpanTrait::at(result, 1);
    let gas_used: u64 = gas_used_felt.try_into().unwrap_or(0);

    // Extract return data if present
    let mut return_data: Array<u8> = array![];
    let return_data_len_felt = *SpanTrait::at(result, 2);
    let return_data_len: u32 = return_data_len_felt.try_into().unwrap_or(0);
    
    if return_data_len > 0 {
        let mut j: u32 = 0;
        while j < return_data_len {
            let idx: usize = (j + 3).try_into().unwrap_or(0);
            if idx < SpanTrait::len(result) {
                let byte_felt = *SpanTrait::at(result, idx);
                let byte: u8 = byte_felt.try_into().unwrap_or(0);
                return_data.append(byte);
            };
            j += 1;
        };
    }

    EvmCallResult { success, return_data: return_data.span(), gas_used }
}
