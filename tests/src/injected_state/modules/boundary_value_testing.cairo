#[starknet::contract]
mod boundary_value_testing {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'boundary_value_testing';

        // Test with minimum non-zero values
        let min_key = 0x1;
        let min_value = 0x1;

        let root1 = hdp.injected_state.write_key(label, min_key, min_value);
        assert!(root1 != 0x0, "Writing minimum values should change root");

        // Test with large values (but not maximum)
        let large_key = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let large_value = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe;

        let root2 = hdp.injected_state.write_key(label, large_key, large_value);
        assert!(root2 != root1, "Writing large values should change root");

        // Verify both values can be read back
        let read_min = hdp.injected_state.read_key(label, min_key).unwrap();
        let read_large = hdp.injected_state.read_key(label, large_key).unwrap();

        assert!(read_min == min_value, "Should read back minimum value");
        assert!(read_large == large_value, "Should read back large value");

        // Verify trie root matches
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == root2, "Final root should match last write");

        // Test reading both keys in sequence
        let read_min_again = hdp.injected_state.read_key(label, min_key).unwrap();
        let read_large_again = hdp.injected_state.read_key(label, large_key).unwrap();

        assert!(read_min_again == min_value, "Second read of minimum value should work");
        assert!(read_large_again == large_value, "Second read of large value should work");

        array![root1, root2, final_root]
    }
}
