#[starknet::contract]
mod read_sequential_key_patterns {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'sequential_key_patterns';

        // Test reading sequential keys
        let sequential_keys = array![0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
        let sequential_values = array![100, 101, 102, 103, 104, 105, 106, 107, 108, 109];

        // Build trie with sequential keys
        let mut current_root = 0x0;
        let mut i = 0;
        loop {
            if i >= sequential_keys.len() {
                break;
            }
            let key = *sequential_keys.at(i);
            let value = *sequential_values.at(i);
            current_root = hdp.injected_state.write_key(label, key, value);
            i += 1;
        }

        // Read all sequential keys and verify
        let mut j = 0;
        loop {
            if j >= sequential_keys.len() {
                break;
            }
            let expected_key = *sequential_keys.at(j);
            let expected_value = *sequential_values.at(j);

            let read_value = hdp.injected_state.read_key(label, expected_key).unwrap();
            assert!(read_value == expected_value, "Sequential key should match expected value");

            j += 1;
        }

        // Verify trie root
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == current_root, "Final trie root should match");

        array![current_root, final_root]
    }
}
