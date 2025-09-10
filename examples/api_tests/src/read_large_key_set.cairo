#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'large_key_set_test';

        // Test reading with a large number of keys (simplified for Cairo)
        let mut current_root = 0x0;

        // Build trie with many keys (20 keys) - write them individually
        current_root = hdp.injected_state.write_key(label, 0, 100);
        current_root = hdp.injected_state.write_key(label, 1, 101);
        current_root = hdp.injected_state.write_key(label, 2, 102);
        current_root = hdp.injected_state.write_key(label, 3, 103);
        current_root = hdp.injected_state.write_key(label, 4, 104);
        current_root = hdp.injected_state.write_key(label, 5, 105);
        current_root = hdp.injected_state.write_key(label, 6, 106);
        current_root = hdp.injected_state.write_key(label, 7, 107);
        current_root = hdp.injected_state.write_key(label, 8, 108);
        current_root = hdp.injected_state.write_key(label, 9, 109);
        current_root = hdp.injected_state.write_key(label, 10, 110);
        current_root = hdp.injected_state.write_key(label, 11, 111);
        current_root = hdp.injected_state.write_key(label, 12, 112);
        current_root = hdp.injected_state.write_key(label, 13, 113);
        current_root = hdp.injected_state.write_key(label, 14, 114);
        current_root = hdp.injected_state.write_key(label, 15, 115);
        current_root = hdp.injected_state.write_key(label, 16, 116);
        current_root = hdp.injected_state.write_key(label, 17, 117);
        current_root = hdp.injected_state.write_key(label, 18, 118);
        current_root = hdp.injected_state.write_key(label, 19, 119);

        // Read all keys and verify
        let read0 = hdp.injected_state.read_key(label, 0).unwrap();
        let read1 = hdp.injected_state.read_key(label, 1).unwrap();
        let read2 = hdp.injected_state.read_key(label, 2).unwrap();
        let read3 = hdp.injected_state.read_key(label, 3).unwrap();
        let read4 = hdp.injected_state.read_key(label, 4).unwrap();
        let read5 = hdp.injected_state.read_key(label, 5).unwrap();
        let read6 = hdp.injected_state.read_key(label, 6).unwrap();
        let read7 = hdp.injected_state.read_key(label, 7).unwrap();
        let read8 = hdp.injected_state.read_key(label, 8).unwrap();
        let read9 = hdp.injected_state.read_key(label, 9).unwrap();
        let read10 = hdp.injected_state.read_key(label, 10).unwrap();
        let read11 = hdp.injected_state.read_key(label, 11).unwrap();
        let read12 = hdp.injected_state.read_key(label, 12).unwrap();
        let read13 = hdp.injected_state.read_key(label, 13).unwrap();
        let read14 = hdp.injected_state.read_key(label, 14).unwrap();
        let read15 = hdp.injected_state.read_key(label, 15).unwrap();
        let read16 = hdp.injected_state.read_key(label, 16).unwrap();
        let read17 = hdp.injected_state.read_key(label, 17).unwrap();
        let read18 = hdp.injected_state.read_key(label, 18).unwrap();
        let read19 = hdp.injected_state.read_key(label, 19).unwrap();

        // Verify values
        assert!(read0 == 100, "Key 0 should be 100");
        assert!(read1 == 101, "Key 1 should be 101");
        assert!(read2 == 102, "Key 2 should be 102");
        assert!(read3 == 103, "Key 3 should be 103");
        assert!(read4 == 104, "Key 4 should be 104");
        assert!(read5 == 105, "Key 5 should be 105");
        assert!(read6 == 106, "Key 6 should be 106");
        assert!(read7 == 107, "Key 7 should be 107");
        assert!(read8 == 108, "Key 8 should be 108");
        assert!(read9 == 109, "Key 9 should be 109");
        assert!(read10 == 110, "Key 10 should be 110");
        assert!(read11 == 111, "Key 11 should be 111");
        assert!(read12 == 112, "Key 12 should be 112");
        assert!(read13 == 113, "Key 13 should be 113");
        assert!(read14 == 114, "Key 14 should be 114");
        assert!(read15 == 115, "Key 15 should be 115");
        assert!(read16 == 116, "Key 16 should be 116");
        assert!(read17 == 117, "Key 17 should be 117");
        assert!(read18 == 118, "Key 18 should be 118");
        assert!(read19 == 119, "Key 19 should be 119");

        // Verify a sample of the results (like the original test)

        let sample_read0 = hdp.injected_state.read_key(label, 0).unwrap();
        let sample_read5 = hdp.injected_state.read_key(label, 5).unwrap();
        let sample_read10 = hdp.injected_state.read_key(label, 10).unwrap();
        let sample_read15 = hdp.injected_state.read_key(label, 15).unwrap();
        let sample_read19 = hdp.injected_state.read_key(label, 19).unwrap();

        assert!(sample_read0 == 100, "Sample key 0 should match expected value");
        assert!(sample_read5 == 105, "Sample key 5 should match expected value");
        assert!(sample_read10 == 110, "Sample key 10 should match expected value");
        assert!(sample_read15 == 115, "Sample key 15 should match expected value");
        assert!(sample_read19 == 119, "Sample key 19 should match expected value");

        // Verify trie root
        let final_root = hdp.injected_state.read_injected_state_trie_root(label).unwrap();
        assert!(final_root == current_root, "Final trie root should match");

        array![current_root, final_root]
    }
}
