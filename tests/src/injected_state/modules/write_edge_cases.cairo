#[starknet::contract]
mod write_edge_cases {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'edge_cases';

        // Test writing with edge case values (large numbers)
        let edge_key = 0x1234567890ABCDEF;
        let edge_value = 0xFEDCBA0987654321;

        // Start with empty trie
        let initial_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(initial_root == 0x0, "Initial trie root should be 0x0");

        // Verify key doesn't exist initially
        let initial_value = hdp.injected_state.read_key(label, edge_key);
        assert!(initial_value.is_none(), "Edge case key should not exist initially");

        // Write edge case key-value pair
        let new_root = hdp.injected_state.write_key(label, edge_key, edge_value);

        // Verify the write was successful
        let written_value = hdp.injected_state.read_key(label, edge_key).unwrap();
        assert!(written_value == edge_value, "Edge case value should match");

        array![new_root, written_value]
    }
}
