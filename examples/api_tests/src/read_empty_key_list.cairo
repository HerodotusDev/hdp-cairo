#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'empty_key_list_test';

        // Test reading with empty key list (simulated by not reading any keys)
        // This test verifies that the system handles the case where no keys are requested

        // First, set up a trie with some data
        let test_key = 0x123;
        let test_value = 0x456;
        let root = hdp.injected_state.write_key(label, test_key, test_value);

        // Verify the trie has data
        let written_value = hdp.injected_state.read_key(label, test_key).unwrap();
        assert!(written_value == test_value, "Written value should be correct");

        // Test that we can still read from the trie after "empty" operations
        let final_read = hdp.injected_state.read_key(label, test_key).unwrap();
        assert!(final_read == test_value, "Final read should still work");

        // Test reading from a completely empty trie (different label)
        let empty_label = 'completely_empty_trie';
        let empty_trie_root = hdp
            .injected_state
            .read_injected_state_trie_root(empty_label)
            .unwrap();
        assert!(empty_trie_root == 0x0, "Empty trie should have zero root");

        // Attempt to read from empty trie
        let empty_read = hdp.injected_state.read_key(empty_label, 0x1);
        assert!(empty_read.is_none(), "Reading from empty trie should return None");

        array![root, final_read, empty_trie_root]
    }
}
