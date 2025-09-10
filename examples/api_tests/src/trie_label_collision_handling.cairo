#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that different trie labels are truly isolated
        let label_a = 'collision_handling_trie_a';
        let label_b = 'collision_handling_trie_b';
        let shared_key = 0x123;
        let value_a = 0x456;
        let value_b = 0x789;

        // Write same key to different tries
        let root_a = hdp.injected_state.write_key(label_a, shared_key, value_a);
        let root_b = hdp.injected_state.write_key(label_b, shared_key, value_b);

        // Verify they have different roots
        assert!(root_a != root_b, "Different trie labels should have different roots");

        // Verify each trie returns its own value
        let resp_a = hdp.injected_state.read_key(label_a, shared_key).unwrap();
        let resp_b = hdp.injected_state.read_key(label_b, shared_key).unwrap();

        assert!(resp_a == value_a, "Trie A should return value_a");
        assert!(resp_b == value_b, "Trie B should return value_b");

        // Verify trie roots are different
        let trie_root_a = hdp.injected_state.read_injected_state_trie_root(label_a).unwrap();
        let trie_root_b = hdp.injected_state.read_injected_state_trie_root(label_b).unwrap();

        assert!(trie_root_a != trie_root_b, "Trie roots should be different");
        assert!(trie_root_a == root_a, "Trie A root should match");
        assert!(trie_root_b == root_b, "Trie B root should match");

        // Test that reading from one trie doesn't affect the other
        let independent_read_a = hdp.injected_state.read_key(label_a, shared_key).unwrap();
        let independent_read_b = hdp.injected_state.read_key(label_b, shared_key).unwrap();

        assert!(independent_read_a == value_a, "Independent read from trie A should work");
        assert!(independent_read_b == value_b, "Independent read from trie B should work");

        array![root_a, root_b, trie_root_a, trie_root_b]
    }
}
