#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Build tries with same keys but different values
        let mut roots = ArrayTrait::new();
        
        // Trie 0: keys with values 0*1000 + key
        let _root0_1 = hdp.injected_state.write_key('collision_trie_0', 0x1, 0x1);
        let _root0_2 = hdp.injected_state.write_key('collision_trie_0', 0x2, 0x2);
        let root0_3 = hdp.injected_state.write_key('collision_trie_0', 0x3, 0x3);
        roots.append(root0_3);

        // Trie 1: keys with values 1*1000 + key
        let _root1_1 = hdp.injected_state.write_key('collision_trie_1', 0x1, 0x1001);
        let _root1_2 = hdp.injected_state.write_key('collision_trie_1', 0x2, 0x1002);
        let root1_3 = hdp.injected_state.write_key('collision_trie_1', 0x3, 0x1003);
        roots.append(root1_3);

        // Trie 2: keys with values 2*1000 + key
        let _root2_1 = hdp.injected_state.write_key('collision_trie_2', 0x1, 0x2001);
        let _root2_2 = hdp.injected_state.write_key('collision_trie_2', 0x2, 0x2002);
        let root2_3 = hdp.injected_state.write_key('collision_trie_2', 0x3, 0x2003);
        roots.append(root2_3);

        // Read same keys from all tries and verify no collision
        // Read key 0x1 from all tries
        let val0_1 = hdp.injected_state.read_key('collision_trie_0', 0x1).unwrap();
        let val1_1 = hdp.injected_state.read_key('collision_trie_1', 0x1).unwrap();
        let val2_1 = hdp.injected_state.read_key('collision_trie_2', 0x1).unwrap();
        
        assert!(val0_1 != val1_1, "Values should differ across tries for key 0x1");
        assert!(val1_1 != val2_1, "Values should differ across tries for key 0x1");
        assert!(val0_1 != val2_1, "Values should differ across tries for key 0x1");

        // Read key 0x2 from all tries
        let val0_2 = hdp.injected_state.read_key('collision_trie_0', 0x2).unwrap();
        let val1_2 = hdp.injected_state.read_key('collision_trie_1', 0x2).unwrap();
        let val2_2 = hdp.injected_state.read_key('collision_trie_2', 0x2).unwrap();
        
        assert!(val0_2 != val1_2, "Values should differ across tries for key 0x2");
        assert!(val1_2 != val2_2, "Values should differ across tries for key 0x2");
        assert!(val0_2 != val2_2, "Values should differ across tries for key 0x2");

        // Read key 0x3 from all tries
        let val0_3 = hdp.injected_state.read_key('collision_trie_0', 0x3).unwrap();
        let val1_3 = hdp.injected_state.read_key('collision_trie_1', 0x3).unwrap();
        let val2_3 = hdp.injected_state.read_key('collision_trie_2', 0x3).unwrap();
        
        assert!(val0_3 != val1_3, "Values should differ across tries for key 0x3");
        assert!(val1_3 != val2_3, "Values should differ across tries for key 0x3");
        assert!(val0_3 != val2_3, "Values should differ across tries for key 0x3");

        // Verify each trie maintains its own state
        let trie_root_0 = hdp.injected_state.read_injected_state_trie_root('collision_trie_0').unwrap();
        let trie_root_1 = hdp.injected_state.read_injected_state_trie_root('collision_trie_1').unwrap();
        let trie_root_2 = hdp.injected_state.read_injected_state_trie_root('collision_trie_2').unwrap();

        assert!(trie_root_0 != 0x0, "Trie 0 should have non-zero root");
        assert!(trie_root_1 != 0x0, "Trie 1 should have non-zero root");
        assert!(trie_root_2 != 0x0, "Trie 2 should have non-zero root");

        array![*roots.at(0), *roots.at(1), *roots.at(2)]
    }
}
