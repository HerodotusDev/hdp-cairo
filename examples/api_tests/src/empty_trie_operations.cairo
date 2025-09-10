#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'empty_trie_operations';

        // Test reading from empty trie
        let empty_root = 0x0;
        let test_key = 0x123;

        // Read from empty trie should return None
        let empty_read = hdp.injected_state.read_key(label, test_key);
        assert!(empty_read.is_none(), "Empty trie should return None for any key");

        // Test writing to empty trie and then reading back
        let value = 0x456;
        let new_root = hdp.injected_state.write_key(label, test_key, value);

        // Writing to empty trie should change root
        assert!(new_root != empty_root, "Writing to empty trie should change root");

        // Should read back the written value
        let read_back = hdp.injected_state.read_key(label, test_key).unwrap();
        assert!(read_back == value, "Should read back the written value");

        // Verify trie root matches
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == new_root, "Final root should match new root");

        // Test reading non-existent key from non-empty trie
        let non_existent_key = 0x789;
        let non_existent_read = hdp.injected_state.read_key(label, non_existent_key);
        assert!(non_existent_read.is_none(), "Non-existent key should return None");

        array![new_root, final_root]
    }
}
