#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test deletion semantics by writing zero value
        let label = 'deletion_semantics_test';
        let k = 0x1;
        let v = 0x64; // 100 in decimal

        // First write a non-zero value
        let r1 = hdp.injected_state.write_key(label, k, v);

        // Then write zero (deletion)
        let r2 = hdp.injected_state.write_key(label, k, 0x0);

        // Deleting a key should change the root
        assert!(r1 != r2, "Deleting a key should change the root");

        // Assert that read returns None after deletion
        let deleted_value = hdp.injected_state.read_key(label, k);
        assert!(deleted_value.is_none(), "Deleted key should return None");

        // Verify the trie root changed
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == r2, "Final root should match deletion root");

        array![r1, r2, final_root]
    }
}
