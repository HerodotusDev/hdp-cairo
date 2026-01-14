#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::eth_call::hdp_backend::TimeAndSpace;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> bool {
        let time_and_space = TimeAndSpace { chain_id: 1, block_number: 21370000 };
        let vitalik_eth_address = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045.try_into().unwrap();
        let usdc_contract_address = 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.try_into().unwrap();
        let calldata = [
            0x70, 0xa0, 0x82, 0x31, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0xd8, 0xda, 0x6b, 0xf2, 0x69, 0x64, 0xaf, 0x9d, 0x7e, 0xed, 0x9e, 0x03,
            0xe5, 0x34, 0x15, 0xd3, 0x7a, 0xa9, 0x60, 0x45,
        ]
            .span();

        // Executing the call via the FAST Cairo 0 executor:
        let result = hdp_cairo::execute_eth_call_zero(
            @hdp, @time_and_space, vitalik_eth_address, usdc_contract_address, calldata,
        );

        println!("Result success: {:?}", result.success);

        return result.success;
    }
}
