#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test proof verification across multiple tries to ensure proofs are valid
        let trie_label_x = 'verify_proofs_trie_x';
        let trie_label_y = 'verify_proofs_trie_y';

        let key1 = 0x100;
        let key2 = 0x200;

        let value_x1 = 0x1001;
        let value_x2 = 0x1002;
        let value_y1 = 0x2001;
        let value_y2 = 0x2002;

        // Build both tries
        let _root_x1 = hdp.injected_state.write_key(trie_label_x, key1, value_x1);
        let _root_x2 = hdp.injected_state.write_key(trie_label_x, key2, value_x2);

        let _root_y1 = hdp.injected_state.write_key(trie_label_y, key1, value_y1);
        let _root_y2 = hdp.injected_state.write_key(trie_label_y, key2, value_y2);

        // Verify each proof by reading from both tries
        let read_x1 = hdp.injected_state.read_key(trie_label_x, key1).unwrap();
        let read_x2 = hdp.injected_state.read_key(trie_label_x, key2).unwrap();
        let read_y1 = hdp.injected_state.read_key(trie_label_y, key1).unwrap();
        let read_y2 = hdp.injected_state.read_key(trie_label_y, key2).unwrap();

        // Verify expected values
        assert!(read_x1 == value_x1, "Trie X key1 should have correct value");
        assert!(read_x2 == value_x2, "Trie X key2 should have correct value");
        assert!(read_y1 == value_y1, "Trie Y key1 should have correct value");
        assert!(read_y2 == value_y2, "Trie Y key2 should have correct value");

        // Test cross-trie proof isolation
        let final_root_x = hdp.injected_state.read_injected_state_trie_root(trie_label_x).unwrap();
        let final_root_y = hdp.injected_state.read_injected_state_trie_root(trie_label_y).unwrap();

        assert!(final_root_x != final_root_y, "Different tries should have different roots");

        // Verify that same keys have different values across tries
        assert!(read_x1 != read_y1, "Same key should have different values across tries");
        assert!(read_x2 != read_y2, "Same key should have different values across tries");

        // Test multiple reads to ensure consistency
        let read_x1_again = hdp.injected_state.read_key(trie_label_x, key1).unwrap();
        let read_x2_again = hdp.injected_state.read_key(trie_label_x, key2).unwrap();
        let read_y1_again = hdp.injected_state.read_key(trie_label_y, key1).unwrap();
        let read_y2_again = hdp.injected_state.read_key(trie_label_y, key2).unwrap();

        assert!(read_x1_again == value_x1, "Second read of trie X key1 should work");
        assert!(read_x2_again == value_x2, "Second read of trie X key2 should work");
        assert!(read_y1_again == value_y1, "Second read of trie Y key1 should work");
        assert!(read_y2_again == value_y2, "Second read of trie Y key2 should work");

        // Verify consistency
        assert!(read_x1 == read_x1_again, "Reads should be consistent");
        assert!(read_x2 == read_x2_again, "Reads should be consistent");
        assert!(read_y1 == read_y1_again, "Reads should be consistent");
        assert!(read_y2 == read_y2_again, "Reads should be consistent");

        array![final_root_x, final_root_y]
    }
}
