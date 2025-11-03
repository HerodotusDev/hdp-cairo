#[starknet::contract]
mod read_sparse_key_distribution {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'sparse_key_distribution';

        // Test reading with sparse key distribution (keys far apart)
        let sparse_keys = array![1, 1000, 1000000, 1000000000];
        let sparse_values = array![0x111, 0x222, 0x333, 0x444];

        // Build trie with sparse keys
        let mut current_root = 0x0;
        let mut i = 0;
        loop {
            if i >= sparse_keys.len() {
                break;
            }
            let key = *sparse_keys.at(i);
            let value = *sparse_values.at(i);
            current_root = hdp.injected_state.write_key(label, key, value);
            i += 1;
        }

        // Read all sparse keys and verify
        let mut j = 0;
        loop {
            if j >= sparse_keys.len() {
                break;
            }
            let expected_key = *sparse_keys.at(j);
            let expected_value = *sparse_values.at(j);

            let read_value = hdp.injected_state.read_key(label, expected_key).unwrap();
            assert!(read_value == expected_value, "Sparse key should match expected value");

            j += 1;
        }

        // Test reading some non-existent keys between sparse keys
        let non_existent_keys = array![500, 500000, 500000000];
        let mut k = 0;
        loop {
            if k >= non_existent_keys.len() {
                break;
            }
            let non_existent_key = *non_existent_keys.at(k);
            let non_existent_value = hdp.injected_state.read_key(label, non_existent_key);
            assert!(non_existent_value.is_none(), "Non-existent sparse key should return None");
            k += 1;
        }

        // Verify trie root
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == current_root, "Final trie root should match");

        array![current_root, final_root]
    }
}
