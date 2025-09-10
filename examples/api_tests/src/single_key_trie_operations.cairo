#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'single_key_trie_operations';
        let key = 0x123;
        let value = 0x456;

        // Test single key write
        let root = hdp.injected_state.write_key(label, key, value);
        assert!(root != 0x0, "Single key write should change root");

        // Test reading the single key
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Should read back the single key value");

        // Test reading non-existent key from single-key trie
        let non_existent_key = 0x789;
        let read_non_existent = hdp.injected_state.read_key(label, non_existent_key);
        assert!(read_non_existent.is_none(), "Non-existent key should return None");

        // Verify trie root matches
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == root, "Final root should match write root");

        // Test multiple reads of the same key
        let read_value2 = hdp.injected_state.read_key(label, key).unwrap();
        let read_value3 = hdp.injected_state.read_key(label, key).unwrap();

        assert!(read_value2 == value, "Second read should work");
        assert!(read_value3 == value, "Third read should work");
        assert!(read_value == read_value2, "All reads should be consistent");
        assert!(read_value2 == read_value3, "All reads should be consistent");

        array![root, final_root]
    }
}
