#[starknet::contract]
mod multiple_key_overrides {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'multiple_key_overrides';
        let key = 0x10;

        // Use deterministic values for testing (similar to seeded RNG in Rust)
        let values = array![
            0x1234567890ABCDEF,
            0xFEDCBA0987654321,
            0x1111111111111111,
            0x2222222222222222,
            0x3333333333333333,
            0x4444444444444444,
            0x5555555555555555,
            0x6666666666666666,
            0x7777777777777777,
            0x8888888888888888,
        ];

        let mut current_root = 0x0;
        let mut root_history = ArrayTrait::new();

        // Perform multiple overwrites of the same key
        let mut i = 0;
        loop {
            if i >= values.len() {
                break;
            }

            let val = *values.at(i);
            let new_root = hdp.injected_state.write_key(label, key, val);

            // Verify the write
            let read_val = hdp.injected_state.read_key(label, key).unwrap();
            assert!(read_val == val, "Value should match after write");

            root_history.append(new_root);
            current_root = new_root;
            i += 1;
        };

        // Verify all roots are unique (except potentially the first one)
        let mut j = 0;
        loop {
            if j >= root_history.len() {
                break;
            }
            let mut k = j + 1;
            loop {
                if k >= root_history.len() {
                    break;
                }
                let root_j = *root_history.at(j);
                let root_k = *root_history.at(k);
                assert!(root_j != root_k, "Roots should be different");
                k += 1;
            };
            j += 1;
        };

        // Verify final value is correct
        let final_value = hdp.injected_state.read_key(label, key).unwrap();
        let expected_final = *values.at(values.len() - 1);
        assert!(final_value == expected_final, "Final value should match last write");

        array![current_root, final_value]
    }
}
