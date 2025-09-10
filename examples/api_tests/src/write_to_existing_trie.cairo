#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'existing_trie';
        let k1 = 0x1;
        let k2 = 0x2;
        let v1 = 0x1;
        let v2 = 0x2;

        // Start with empty trie
        let initial_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(initial_root == 0x0, "Initial trie root should be 0x0");

        // First write: k1 -> v1
        let root1 = hdp.injected_state.write_key(label, k1, v1);
        assert!(root1 != 0x0, "Root must change after first write");

        // Verify first write
        let read_v1 = hdp.injected_state.read_key(label, k1).unwrap();
        assert!(read_v1 == v1, "First value should be correct");

        // Verify k2 doesn't exist yet
        let k2_initial = hdp.injected_state.read_key(label, k2);
        assert!(k2_initial.is_none(), "k2 should not exist yet");

        // Second write: k2 -> v2
        let root2 = hdp.injected_state.write_key(label, k2, v2);
        assert!(root2 != root1, "Root must change after second write");

        // Verify both keys exist with correct values
        let read_v1_final = hdp.injected_state.read_key(label, k1).unwrap();
        let read_v2_final = hdp.injected_state.read_key(label, k2).unwrap();
        assert!(read_v1_final == v1, "k1 value should still be correct");
        assert!(read_v2_final == v2, "k2 value should be correct");

        array![initial_root, root1, root2, read_v1_final, read_v2_final]
    }
}
