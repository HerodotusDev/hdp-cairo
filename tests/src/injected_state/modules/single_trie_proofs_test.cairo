#[starknet::contract]
mod single_trie_proofs_test {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test state proofs for a single trie with multiple key-value pairs
        let label = 'single_trie_proofs_test';

        // Test with a smaller set of keys for Cairo constraints
        let k1 = 0x1;
        let v1 = 0x64; // 100
        let k2 = 0x2;
        let v2 = 0xC8; // 200
        let k3 = 0x3;
        let v3 = 0x12C; // 300

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

        assert!(read_k1 == v1, "Key 1 should have correct value");
        assert!(read_k2 == v2, "Key 2 should have correct value");
        assert!(read_k3 == v3, "Key 3 should have correct value");

        // Verify trie root is consistent
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == current_root, "Final root should match current root");

        // Test reading non-existent key
        let non_existent_key = 0x4;
        let non_existent_read = hdp.injected_state.read_key(label, non_existent_key);
        assert!(non_existent_read.is_none(), "Non-existent key should return None");

        // Test multiple reads of the same keys
        let read_k1_again = hdp.injected_state.read_key(label, k1).unwrap();
        let read_k2_again = hdp.injected_state.read_key(label, k2).unwrap();
        let read_k3_again = hdp.injected_state.read_key(label, k3).unwrap();

        assert!(read_k1_again == v1, "Second read of key 1 should work");
        assert!(read_k2_again == v2, "Second read of key 2 should work");
        assert!(read_k3_again == v3, "Second read of key 3 should work");

        array![current_root, final_root]
    }
}
