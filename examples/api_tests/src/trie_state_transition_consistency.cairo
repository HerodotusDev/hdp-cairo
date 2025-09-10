#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'state_transition_consistency';
        let key = 0x123;
        let value1 = 0x456;
        let value2 = 0x789;
        let value3 = 0xABC;

        // Write sequence: value1 -> value2 -> value3
        let root1 = hdp.injected_state.write_key(label, key, value1);
        let root2 = hdp.injected_state.write_key(label, key, value2);
        let root3 = hdp.injected_state.write_key(label, key, value3);

        // Verify roots change at each step
        assert!(0x0 != root1, "First write should change root");
        assert!(root1 != root2, "Second write should change root");
        assert!(root2 != root3, "Third write should change root");

        // Verify each state can be read correctly
        // Note: In Cairo, we can only read the final state, but we can verify
        // that the final state is correct
        let final_read = hdp.injected_state.read_key(label, key).unwrap();
        assert!(final_read == value3, "Final state should have value3");

        // Verify trie root matches final state
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == root3, "Final root should match root3");

        // Test that we can still read the key multiple times consistently
        let read1 = hdp.injected_state.read_key(label, key).unwrap();
        let read2 = hdp.injected_state.read_key(label, key).unwrap();
        let read3 = hdp.injected_state.read_key(label, key).unwrap();

        assert!(read1 == value3, "First read should return value3");
        assert!(read2 == value3, "Second read should return value3");
        assert!(read3 == value3, "Third read should return value3");
        assert!(read1 == read2, "All reads should be consistent");
        assert!(read2 == read3, "All reads should be consistent");

        array![root1, root2, root3, final_root]
    }
}
