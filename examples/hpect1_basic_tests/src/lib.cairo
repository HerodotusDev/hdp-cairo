// HPECT1 Basic Tests - Minimal tests using Cairo Zero EVM
// 1. Direct HPECT2 math (pure function)
// 2. HPECT1 -> HPECT2 delegate call
//
// Uses Cairo Zero EVM via syscall for provable execution

#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::TimeAndSpace;
    use hdp_cairo::execute_eth_call_zero;
    use starknet::EthAddress;

    #[storage]
    struct Storage {}

    const HPECT1_ADDRESS: felt252 = 0xe5d5bc62Cf36FB14eFd8c32238c5d39B15bbFFd1;
    const HPECT2_ADDRESS: felt252 = 0x6c7853Cd36c9189c87CDD82655Da6d0d6e4df87f;
    const SEPOLIA_CHAIN_ID: felt252 = 11155111;
    const BLOCK_NUMBER: u64 = 9689123;
    const SENDER_ADDRESS: felt252 = 0x946f7cc10fb0a6dc70860b6cf55ef2c722cc7e1a;

    fn decode_u256(data: Span<u8>) -> u256 {
        let mut value: u256 = 0;
        let mut i: usize = 0;
        let len = data.len();
        while i < len && i < 32 {
            value = value * 256 + (*data.at(i)).into();
            i += 1;
        };
        value
    }

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let time_and_space = TimeAndSpace { 
            chain_id: SEPOLIA_CHAIN_ID, 
            block_number: BLOCK_NUMBER.into() 
        };
        
        let hpect1: EthAddress = HPECT1_ADDRESS.try_into().unwrap();
        let hpect2: EthAddress = HPECT2_ADDRESS.try_into().unwrap();
        let sender: EthAddress = SENDER_ADDRESS.try_into().unwrap();

        let mut results: Array<felt252> = ArrayTrait::new();
        let mut passed: u32 = 0;

        println!("=== HPECT1 Basic Tests (Cairo Zero EVM) ===");
        println!("");

        // ========================================
        // Test 1: Direct HPECT2 - calculateForTestingCalls(100)
        // Result: 100 * 21 + 37 = 2137
        // ========================================
        println!("Test 1: HPECT2.calculateForTestingCalls(100)");
        let calldata1 = [
            0x56_u8, 0x17_u8, 0x74_u8, 0xc3_u8,
            0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8,
            0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8,
            0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8, 0x00_u8,
            0x00_u8, 0x00_u8, 0x00_u8, 0x64_u8
        ].span();
        
        // Execute via Cairo Zero EVM syscall
        let result1 = execute_eth_call_zero(@hdp, @time_and_space, sender, hpect2, calldata1);
        
        println!("  Success: {}", result1.success);
        println!("  Return data length: {}", result1.return_data.len());
        if result1.success && result1.return_data.len() >= 32 {
            let actual = decode_u256(result1.return_data);
            let expected: u256 = 2137;
            println!("  Expected: {}", expected);
            println!("  Actual:   {}", actual);
            if actual == expected {
                println!("  Status:   PASS");
                passed += 1;
            } else {
                println!("  Status:   FAIL (value mismatch)");
            }
        } else {
            println!("  Status:   FAIL (call failed or insufficient return data)");
        }
        results.append(if result1.success { 1 } else { 0 });
        println!("");

        // ========================================
        // Test 2: HPECT1 delegate call -> HPECT2
        // performDelegateCallWithReturn() -> 44914
        // ========================================
        println!("Test 2: HPECT1.performDelegateCallWithReturn()");
        let calldata2 = [0xe5_u8, 0x8e_u8, 0x6c_u8, 0x6d_u8].span();
        
        // Execute via Cairo Zero EVM syscall
        let result2 = execute_eth_call_zero(@hdp, @time_and_space, sender, hpect1, calldata2);
        
        println!("  Success: {}", result2.success);
        println!("  Return data length: {}", result2.return_data.len());
        if result2.success && result2.return_data.len() >= 32 {
            let actual = decode_u256(result2.return_data);
            let expected: u256 = 44914;
            println!("  Expected: {}", expected);
            println!("  Actual:   {}", actual);
            if actual == expected {
                println!("  Status:   PASS");
                passed += 1;
            } else {
                println!("  Status:   FAIL (value mismatch)");
            }
        } else {
            println!("  Status:   FAIL (call failed or insufficient return data)");
        }
        results.append(if result2.success { 1 } else { 0 });
        println!("");

        // ========================================
        // Test 3: Basic Arithmetic (ADD opcode)
        // Simple bytecode: PUSH1 0x05, PUSH1 0x03, ADD, PUSH1 0x00, MSTORE, PUSH1 0x20, PUSH1 0x00, RETURN
        // Result: 5 + 3 = 8
        // Note: This test requires bytecode to be deployed at a test address
        // For now, we'll skip if the contract doesn't exist
        // ========================================
        println!("Test 3: Basic Arithmetic (ADD: 5 + 3 = 8)");
        println!("  Note: This test requires a contract with simple ADD bytecode");
        println!("  Status: SKIP (requires bytecode deployment)");
        println!("");

        // Summary
        println!("=== Summary ===");
        println!("Passed: {}/2", passed);
        results.append(passed.into());
        
        results
    }
}
