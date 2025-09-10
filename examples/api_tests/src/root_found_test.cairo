#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that an existing trie_root can be found and used
        let trie_label = 'root_found_test';
        let test_key = 0x1;
        let test_value = 0x1;

        // Write to create an existing trie
        let created_root = hdp.injected_state.write_key(trie_label, test_key, test_value);
        assert!(created_root != 0x0, "Created trie should have non-zero root");

        // Verify we can read from the existing trie
        let read_value = hdp.injected_state.read_key(trie_label, test_key).unwrap();
        assert!(read_value == test_value, "Should read back the written value");

        // Verify trie root matches
        let current_root = hdp.injected_state.read_injected_state_trie_root(trie_label).unwrap();
        assert!(current_root == created_root, "Current root should match created root");

        // Test reading non-existent key from existing trie
        let non_existent_key = 0x2;
        let non_existent_read = hdp.injected_state.read_key(trie_label, non_existent_key);
        assert!(non_existent_read.is_none(), "Non-existent key should return None");

        // Test writing additional key to existing trie
        let additional_key = 0x3;
        let additional_value = 0x3;
        let updated_root = hdp.injected_state.write_key(trie_label, additional_key, additional_value);
        assert!(updated_root != created_root, "Adding key should change root");

        // Verify both keys exist
        let read_key1 = hdp.injected_state.read_key(trie_label, test_key).unwrap();
        let read_key3 = hdp.injected_state.read_key(trie_label, additional_key).unwrap();
        assert!(read_key1 == test_value, "Original key should still exist");
        assert!(read_key3 == additional_value, "Additional key should exist");

        array![created_root, current_root, updated_root]
    }
}
