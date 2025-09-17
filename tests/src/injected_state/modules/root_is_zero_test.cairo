#[starknet::contract]
mod root_is_zero_test {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test that a trie_root of zero returns expected behavior
        let trie_label = 'root_is_zero_test';
        let trie_root = 0x0;

        // Read from zero root should return None
        let test_key = 0x123;
        let zero_read = hdp.injected_state.read_key(trie_label, test_key);
        assert!(zero_read.is_none(), "Reading from zero root should return None");

        // Verify trie root is zero
        let current_root = hdp.injected_state.read_injected_state_trie_root(trie_label).unwrap();
        assert!(current_root == trie_root, "Trie root should be zero");

        // Test that we can still write to the trie after reading from zero root
        let test_value = 0x456;
        let new_root = hdp.injected_state.write_key(trie_label, test_key, test_value);
        assert!(new_root != trie_root, "Writing should change root from zero");

        // Verify the write worked
        let written_value = hdp.injected_state.read_key(trie_label, test_key).unwrap();
        assert!(written_value == test_value, "Written value should be correct");

        // Verify final root
        let final_root = hdp.injected_state.read_injected_state_trie_root(trie_label).unwrap();
        assert!(final_root == new_root, "Final root should match new root");

        array![trie_root, new_root, final_root]
    }
}
