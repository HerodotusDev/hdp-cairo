#[starknet::contract]
mod multiple_tries_proofs_test {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test state proofs across multiple different tries to ensure no data collision
        let trie_label_a = 'multiple_tries_proofs_a';
        let trie_label_b = 'multiple_tries_proofs_b';
        let trie_label_c = 'multiple_tries_proofs_c';

        // Same keys but different values for each trie
        let key1 = 0x1;
        let key2 = 0x2;
        let key3 = 0x3;

        // Values for trie A
        let value_a1 = 0xA01;
        let value_a2 = 0xA02;
        let value_a3 = 0xA03;

        // Values for trie B
        let value_b1 = 0xB01;
        let value_b2 = 0xB02;

        // Values for trie C
        let value_c1 = 0xC01;

        // Build trie A
        let _root_a1 = hdp.injected_state.write_key(trie_label_a, key1, value_a1);
        let _root_a2 = hdp.injected_state.write_key(trie_label_a, key2, value_a2);
        let _root_a3 = hdp.injected_state.write_key(trie_label_a, key3, value_a3);

        // Build trie B
        let _root_b1 = hdp.injected_state.write_key(trie_label_b, key1, value_b1);
        let _root_b2 = hdp.injected_state.write_key(trie_label_b, key2, value_b2);

        // Build trie C
        let _root_c1 = hdp.injected_state.write_key(trie_label_c, key1, value_c1);

        // Test reading from multiple tries
        // Read from trie A
        let read_a1 = hdp.injected_state.read_key(trie_label_a, key1).unwrap();
        let read_a2 = hdp.injected_state.read_key(trie_label_a, key2).unwrap();
        let read_a3 = hdp.injected_state.read_key(trie_label_a, key3).unwrap();

        assert!(read_a1 == value_a1, "Trie A key1 should have correct value");
        assert!(read_a2 == value_a2, "Trie A key2 should have correct value");
        assert!(read_a3 == value_a3, "Trie A key3 should have correct value");

        // Read from trie B
        let read_b1 = hdp.injected_state.read_key(trie_label_b, key1).unwrap();
        let read_b2 = hdp.injected_state.read_key(trie_label_b, key2).unwrap();
        let read_b3 = hdp.injected_state.read_key(trie_label_b, key3);

        assert!(read_b1 == value_b1, "Trie B key1 should have correct value");
        assert!(read_b2 == value_b2, "Trie B key2 should have correct value");
        assert!(read_b3.is_none(), "Trie B key3 should not exist");

        // Read from trie C
        let read_c1 = hdp.injected_state.read_key(trie_label_c, key1).unwrap();
        let read_c2 = hdp.injected_state.read_key(trie_label_c, key2);

        assert!(read_c1 == value_c1, "Trie C key1 should have correct value");
        assert!(read_c2.is_none(), "Trie C key2 should not exist");

        // Verify trie roots are different
        let final_root_a = hdp.injected_state.read_injected_state_trie_root(trie_label_a).unwrap();
        let final_root_b = hdp.injected_state.read_injected_state_trie_root(trie_label_b).unwrap();
        let final_root_c = hdp.injected_state.read_injected_state_trie_root(trie_label_c).unwrap();

        assert!(final_root_a != final_root_b, "Trie A and B should have different roots");
        assert!(final_root_b != final_root_c, "Trie B and C should have different roots");
        assert!(final_root_a != final_root_c, "Trie A and C should have different roots");

        // Test cross-trie isolation
        assert!(read_a1 != read_b1, "Same key should have different values across tries");
        assert!(read_a1 != read_c1, "Same key should have different values across tries");
        assert!(read_b1 != read_c1, "Same key should have different values across tries");

        array![final_root_a, final_root_b, final_root_c]
    }
}
