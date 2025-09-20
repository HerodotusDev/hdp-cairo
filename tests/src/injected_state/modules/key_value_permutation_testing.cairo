#[starknet::contract]
mod key_value_permutation_testing {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'key_value_permutation_testing';

        // Test various key-value combinations (using only safe, non-zero values)
        let k1 = 0x1;
        let v1 = 0x64; // 100 in decimal
        let k2 = 0x2;
        let v2 = 0xC8; // 200 in decimal
        let k3 = 0x123;
        let v3 = 0x456;

        let mut current_root = 0x0;

        // Write first key-value pair
        current_root = hdp.injected_state.write_key(label, k1, v1);

        // Write second key-value pair
        current_root = hdp.injected_state.write_key(label, k2, v2);

        // Write third key-value pair
        current_root = hdp.injected_state.write_key(label, k3, v3);

        // Verify all values can be read back
        let read_k1 = hdp.injected_state.read_key(label, k1).unwrap();
        let read_k2 = hdp.injected_state.read_key(label, k2).unwrap();
        let read_k3 = hdp.injected_state.read_key(label, k3).unwrap();

        assert!(read_k1 == v1, "Key 1 should match expected value");
        assert!(read_k2 == v2, "Key 2 should match expected value");
        assert!(read_k3 == v3, "Key 3 should match expected value");

        // Verify trie root matches
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == current_root, "Final root should match last write");

        // Test reading all keys in different order
        let read_k3_again = hdp.injected_state.read_key(label, k3).unwrap();
        let read_k1_again = hdp.injected_state.read_key(label, k1).unwrap();
        let read_k2_again = hdp.injected_state.read_key(label, k2).unwrap();

        assert!(read_k3_again == v3, "Key 3 should still work");
        assert!(read_k1_again == v1, "Key 1 should still work");
        assert!(read_k2_again == v2, "Key 2 should still work");

        array![current_root, final_root]
    }
}
