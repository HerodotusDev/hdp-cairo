#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that a trie_root cannot be found with the wrong label
        let trie_label_a = 'root_found_wrong_label_a';
        let trie_label_b = 'root_found_wrong_label_b';
        let test_key = 0x1;
        let test_value = 0x1;

        // Create trie with label A
        let root_a = hdp.injected_state.write_key(trie_label_a, test_key, test_value);
        assert!(root_a != 0x0, "Trie A should have non-zero root");

        // Verify we can read from trie A
        let read_a = hdp.injected_state.read_key(trie_label_a, test_key).unwrap();
        assert!(read_a == test_value, "Trie A should return correct value");

        // Verify trie B is empty (zero root)
        let root_b = hdp.injected_state.read_injected_state_trie_root(trie_label_b).unwrap();
        assert!(root_b == 0x0, "Trie B should have zero root");

        // Try to read from trie B with same key - should return None
        let read_b = hdp.injected_state.read_key(trie_label_b, test_key);
        assert!(read_b.is_none(), "Trie B should return None for non-existent key");

        // Verify trie isolation - writing to trie B shouldn't affect trie A
        let additional_key = 0x2;
        let additional_value = 0x2;
        let root_b_updated = hdp.injected_state.write_key(trie_label_b, additional_key, additional_value);
        assert!(root_b_updated != 0x0, "Trie B should have non-zero root after write");

        // Verify trie A is unchanged
        let read_a_again = hdp.injected_state.read_key(trie_label_a, test_key).unwrap();
        assert!(read_a_again == test_value, "Trie A should be unchanged");

        // Verify trie B has the new value
        let read_b_new = hdp.injected_state.read_key(trie_label_b, additional_key).unwrap();
        assert!(read_b_new == additional_value, "Trie B should have new value");

        // Verify roots are different
        let final_root_a = hdp.injected_state.read_injected_state_trie_root(trie_label_a).unwrap();
        let final_root_b = hdp.injected_state.read_injected_state_trie_root(trie_label_b).unwrap();
        assert!(final_root_a != final_root_b, "Different tries should have different roots");

        array![root_a, root_b_updated, final_root_a, final_root_b]
    }
}
