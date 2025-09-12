#[starknet::contract]
mod multi_trie_deterministic_reads {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let (l1, l2, l3) = ('deterministic_trie_1', 'deterministic_trie_2', 'deterministic_trie_3');
        let (k1, k2, k3) = (10, 20, 30);

        // Build 3 tries with overlapping and unique keys
        // Trie 1: k1->100, k2->200
        let _r1_k1 = hdp.injected_state.write_key(l1, k1, 100);
        let r1 = hdp.injected_state.write_key(l1, k2, 200);

        // Trie 2: k1->1000, k3->3000
        let _r2_k1 = hdp.injected_state.write_key(l2, k1, 1000);
        let r2 = hdp.injected_state.write_key(l2, k3, 3000);

        // Trie 3: k2->20000
        let r3 = hdp.injected_state.write_key(l3, k2, 20000);

        // Read all keys from all tries (mix of existing/non-existing)
        // Trie 1 reads
        let t1_k1 = hdp.injected_state.read_key(l1, k1).unwrap();
        let t1_k2 = hdp.injected_state.read_key(l1, k2).unwrap();
        let t1_k3 = hdp.injected_state.read_key(l1, k3);

        assert!(t1_k1 == 100, "Trie 1 k1 should be 100");
        assert!(t1_k2 == 200, "Trie 1 k2 should be 200");
        assert!(t1_k3.is_none(), "Trie 1 k3 should not exist");

        // Trie 2 reads
        let t2_k1 = hdp.injected_state.read_key(l2, k1).unwrap();
        let t2_k2 = hdp.injected_state.read_key(l2, k2);
        let t2_k3 = hdp.injected_state.read_key(l2, k3).unwrap();

        assert!(t2_k1 == 1000, "Trie 2 k1 should be 1000");
        assert!(t2_k2.is_none(), "Trie 2 k2 should not exist");
        assert!(t2_k3 == 3000, "Trie 2 k3 should be 3000");

        // Trie 3 reads
        let t3_k1 = hdp.injected_state.read_key(l3, k1);
        let t3_k2 = hdp.injected_state.read_key(l3, k2).unwrap();
        let t3_k3 = hdp.injected_state.read_key(l3, k3);

        assert!(t3_k1.is_none(), "Trie 3 k1 should not exist");
        assert!(t3_k2 == 20000, "Trie 3 k2 should be 20000");
        assert!(t3_k3.is_none(), "Trie 3 k3 should not exist");

        // Verify deterministic behavior - same reads should return same results
        let t1_k1_repeat = hdp.injected_state.read_key(l1, k1).unwrap();
        let t2_k1_repeat = hdp.injected_state.read_key(l2, k1).unwrap();
        let t3_k2_repeat = hdp.injected_state.read_key(l3, k2).unwrap();

        assert!(t1_k1_repeat == t1_k1, "Repeated read should be deterministic");
        assert!(t2_k1_repeat == t2_k1, "Repeated read should be deterministic");
        assert!(t3_k2_repeat == t3_k2, "Repeated read should be deterministic");

        array![r1, r2, r3]
    }
}
