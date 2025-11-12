use starknet::EthAddress;
use crate::HDP;
use crate::eth_call::evm::gas::calculate_intrinsic_gas_cost;
use crate::eth_call::evm::interpreter::EVMImpl;
use crate::eth_call::utils::bytecode::OriginalByteCode;
use crate::eth_call::utils::eth_transaction::common::TxKind;
use crate::eth_call::utils::eth_transaction::eip1559::TxEip1559;
use crate::eth_call::utils::eth_transaction::transaction::Transaction;
use super::evm::model::TransactionResult;
use super::hdp_backend::TimeAndSpace;

pub fn execute_eth_call(
    hdp: @HDP,
    time_and_space: @TimeAndSpace,
    sender: EthAddress,
    target: EthAddress,
    calldata: Span<u8>,
) -> TransactionResult {
    let tx = Transaction::Eip1559(
        TxEip1559 {
            chain_id: (*time_and_space.chain_id).try_into().unwrap(),
            nonce: 0,
            gas_limit: 50_000_000,
            max_fee_per_gas: 1_000_000_000,
            max_priority_fee_per_gas: 500_000,
            to: TxKind::Call(target),
            value: 0,
            access_list: [].span(),
            input: calldata,
        },
    );

    let intrinsic_gas_cost = calculate_intrinsic_gas_cost(@tx);

    EVMImpl::process_transaction(sender, tx, intrinsic_gas_cost, Some(hdp), time_and_space)
}
