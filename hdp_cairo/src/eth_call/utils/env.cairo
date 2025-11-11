use hdp_cairo::HDP;
use starknet::EthAddress;
use crate::eth_call::evm::model::Environment;
use crate::eth_call::hdp_backend::{
    TimeAndSpace, fetch_base_fee, fetch_coinbase, fetch_gas_limit, fetch_number, fetch_timestamp,
};

/// Populate an Environment with Starknet syscalls.
pub fn get_env(
    origin: EthAddress, gas_price: u128, hdp: Option<@HDP>, time_and_space: @TimeAndSpace,
) -> Environment {
    Environment {
        origin,
        gas_price,
        chain_id: (*time_and_space.chain_id).try_into().unwrap(),
        // --------------------
        // TODO: @herodotus [prevrundao] random stuff in here for now
        prevrandao: 0x2137,
        // --------------------
        block_number: fetch_number(hdp, time_and_space),
        block_gas_limit: fetch_gas_limit(hdp, time_and_space),
        block_timestamp: fetch_timestamp(hdp, time_and_space),
        coinbase: fetch_coinbase(hdp, time_and_space),
        base_fee: fetch_base_fee(hdp, time_and_space),
        state: Default::default(),
    }
}
