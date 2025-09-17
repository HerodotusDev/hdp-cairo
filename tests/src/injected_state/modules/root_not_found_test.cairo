#[starknet::contract]
mod root_not_found_test {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that reading from a non-existent trie_root behaves correctly
        let trie_label = 'root_not_found_test';
        let _non_existent_root = 0x456;

        // Read from non-existent root should return None
        let test_key = 0x123;
        let non_existent_read = hdp.injected_state.read_key(trie_label, test_key);
        assert!(non_existent_read.is_none(), "Reading from non-existent root should return None");

        // Verify current trie root is zero (empty trie)
        let current_root = hdp.injected_state.read_injected_state_trie_root(trie_label).unwrap();
        assert!(current_root == 0x0, "Empty trie should have zero root");

        // Test that we can still write to the trie
        let test_value = 0x789;
        let new_root = hdp.injected_state.write_key(trie_label, test_key, test_value);
        assert!(new_root != 0x0, "Writing should change root from zero");

        // Verify the write worked
        let written_value = hdp.injected_state.read_key(trie_label, test_key).unwrap();
        assert!(written_value == test_value, "Written value should be correct");

        // Verify final root
        let final_root = hdp.injected_state.read_injected_state_trie_root(trie_label).unwrap();
        assert!(final_root == new_root, "Final root should match new root");

        array![current_root, new_root, final_root]
    }
}
