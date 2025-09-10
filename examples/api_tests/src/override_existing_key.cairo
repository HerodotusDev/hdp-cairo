#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'override_existing_key';
        let key = 0x1;
        let v1 = 0x1;
        let v2 = 0x2;

        // Start with empty trie
        let initial_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(initial_root == 0x0, "Initial trie root should be 0x0");

        // First write: key -> v1
        let root1 = hdp.injected_state.write_key(label, key, v1);

        // Verify first write
        let read_v1 = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_v1 == v1, "Initial value should be v1");

        // Override: key -> v2
        let root2 = hdp.injected_state.write_key(label, key, v2);
        assert!(root1 != root2, "Overwriting key should change the root");

        // Verify override was successful
        let read_v2 = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_v2 == v2, "Overridden value should be v2");

        array![root1, root2, read_v2]
    }
}
