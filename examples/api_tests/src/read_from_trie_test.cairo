#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'basic_read_test';
        let key = 0x1;
        let val = 0x1;

        // Write to the trie first
        let root = hdp.injected_state.write_key(label, key, val);

        // Test direct read
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == val, "Read value should match written value");

        // Verify trie root matches
        let trie_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(trie_root == root, "Trie root should match");

        array![root, read_value, trie_root]
    }
}
