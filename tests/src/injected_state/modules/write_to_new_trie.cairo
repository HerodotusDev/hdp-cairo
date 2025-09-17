#[starknet::contract]
mod write_to_new_trie {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'simple_trie';
        let key = 0x1;
        let val = 0x1;

        // Read initial trie root (should be 0x0 for new trie)
        let initial_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(initial_root == 0x0, "Initial trie root should be 0x0");

        // Verify key doesn't exist initially
        let initial_value = hdp.injected_state.read_key(label, key);
        assert!(initial_value.is_none(), "Key should not exist initially");

        // Write to the trie
        let new_root = hdp.injected_state.write_key(label, key, val);

        // Verify the write was successful
        let written_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(written_value == val, "Written value should match");

        // Verify trie root changed
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == new_root, "Final trie root should match returned root");
        assert!(final_root != initial_root, "Trie root should have changed");

        array![new_root, final_root]
    }
}
