#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::eth_call::hdp_backend::TimeAndSpace;
    use hdp_cairo::eth_call::utils::helpers::load_word;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> u256 {
        // A long time ago in a galaxy far, far away....
        let time_and_space = TimeAndSpace { chain_id: 1, block_number: 21370000 };
        // Sender - vitalik.eth on Ethereum:
        let vitalik_eth_address = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.try_into().unwrap();
        // Target - USDC on Ethereum:
        let usdc_contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.try_into().unwrap();
        // Getting the calldata for the balanceOf function:
        // cast calldata "balanceOf(address)" 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
        // Result: 0x70a08231000000000000000000000000d8da6bf26964af9d7eed9e03e53415d37aa96045
        let calldata = [
            0x70, 0xa0, 0x82, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0xd8, 0xda, 0x6b, 0xf2, 0x69, 0x64, 0xaf, 0x9d, 0x7e, 0xed, 0x9e, 0x03,
            0xe5, 0x34, 0x15, 0xd3, 0x7a, 0xa9, 0x60, 0x45,
        ]
            .span();

        // Executing the call:
        let result = hdp_cairo::execute_eth_call(
            @hdp, @time_and_space, vitalik_eth_address, usdc_contract_address, calldata,
        );

        // result.return_data is a Span<u8>, so we need to convert it to a u256:
        let return_data_len = result.return_data.len();
        let vitaliks_balance: u256 = load_word(return_data_len, result.return_data);

        println!("Result success: {:?}", result.success);
        println!("Result gas_used: {:?}", result.gas_used);
        println!("Result return_data: {:?}", result.return_data);
        println!("Vitalik's USDC balance: {:?}", vitaliks_balance);

        // If you want you can also read decimals() function from the USDC contract,
        // and divide the balance by 10^decimals to get the actual balance.
        // Just make another call and use the result!

        return vitaliks_balance;
    }
}
