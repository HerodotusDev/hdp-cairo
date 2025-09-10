#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let la = 'trie_a_random_reads';
        let lb = 'trie_b_random_reads';
        let lc = 'trie_c_random_reads';

        // Build tries with small fixed data sets
        // Trie A: keys 0x1->0xA1, 0x2->0xA2
        let _root_a1 = hdp.injected_state.write_key(la, 0x1, 0xA1);
        let root_a = hdp.injected_state.write_key(la, 0x2, 0xA2);

        // Trie B: keys 0x1->0xB1, 0x3->0xB3
        let _root_b1 = hdp.injected_state.write_key(lb, 0x1, 0xB1);
        let root_b = hdp.injected_state.write_key(lb, 0x3, 0xB3);

        // Trie C: key 0x2->0xC2
        let root_c = hdp.injected_state.write_key(lc, 0x2, 0xC2);

        // Test random reads from different tries
        let test_keys = array![0x1, 0x2, 0x3, 0x4];
        let mut results = ArrayTrait::new();

        // For each test key, read from all three tries
        let mut i = 0;
        loop {
            if i >= test_keys.len() {
                break;
            }
            let key = *test_keys.at(i);

            // Read from trie A
            let value_a = hdp.injected_state.read_key(la, key);
            if value_a.is_some() {
                let val = value_a.unwrap();
                if key == 0x1 {
                    assert!(val == 0xA1, "Trie A key 0x1 should be 0xA1");
                } else if key == 0x2 {
                    assert!(val == 0xA2, "Trie A key 0x2 should be 0xA2");
                }
            } else {
                // Key doesn't exist in trie A
                if key == 0x3 || key == 0x4 { // Expected to not exist
                } else {
                    panic!("Unexpected missing key in trie A");
                }
            }

            // Read from trie B
            let value_b = hdp.injected_state.read_key(lb, key);
            if value_b.is_some() {
                let val = value_b.unwrap();
                if key == 0x1 {
                    assert!(val == 0xB1, "Trie B key 0x1 should be 0xB1");
                } else if key == 0x3 {
                    assert!(val == 0xB3, "Trie B key 0x3 should be 0xB3");
                }
            } else {
                // Key doesn't exist in trie B
                if key == 0x2 || key == 0x4 { // Expected to not exist
                } else {
                    panic!("Unexpected missing key in trie B");
                }
            }

            // Read from trie C
            let value_c = hdp.injected_state.read_key(lc, key);
            if value_c.is_some() {
                let val = value_c.unwrap();
                if key == 0x2 {
                    assert!(val == 0xC2, "Trie C key 0x2 should be 0xC2");
                }
            } else {
                // Key doesn't exist in trie C
                if key == 0x1 || key == 0x3 || key == 0x4 { // Expected to not exist
                } else {
                    panic!("Unexpected missing key in trie C");
                }
            }

            results.append(key);
            i += 1;
        };

        array![root_a, root_b, root_c]
    }
}
