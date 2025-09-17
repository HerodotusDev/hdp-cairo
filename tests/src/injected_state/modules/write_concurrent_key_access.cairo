#[starknet::contract]
mod write_concurrent_key_access {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'concurrent_access';

        // Test writing to different keys in a pattern that might stress concurrent access
        let key1 = 0x001;
        let key2 = 0x100;
        let key3 = 0x200;
        let key4 = 0x300;
        let key5 = 0x400;

        let mut current_root = 0x0;

        // Write to each key with a unique value
        // Write key1 with value 1000
        let new_root = hdp.injected_state.write_key(label, key1, 1000);
        let read_value = hdp.injected_state.read_key(label, key1).unwrap();
        assert!(read_value == 1000, "Key1 should have value 1000");
        assert!(new_root != current_root, "Writing key1 should change root");
        current_root = new_root;

        // Write key2 with value 2000
        let new_root = hdp.injected_state.write_key(label, key2, 2000);
        let read_value = hdp.injected_state.read_key(label, key2).unwrap();
        assert!(read_value == 2000, "Key2 should have value 2000");
        assert!(new_root != current_root, "Writing key2 should change root");
        current_root = new_root;

        // Write key3 with value 3000
        let new_root = hdp.injected_state.write_key(label, key3, 3000);
        let read_value = hdp.injected_state.read_key(label, key3).unwrap();
        assert!(read_value == 3000, "Key3 should have value 3000");
        assert!(new_root != current_root, "Writing key3 should change root");
        current_root = new_root;

        // Write key4 with value 4000
        let new_root = hdp.injected_state.write_key(label, key4, 4000);
        let read_value = hdp.injected_state.read_key(label, key4).unwrap();
        assert!(read_value == 4000, "Key4 should have value 4000");
        assert!(new_root != current_root, "Writing key4 should change root");
        current_root = new_root;

        // Write key5 with value 5000
        let new_root = hdp.injected_state.write_key(label, key5, 5000);
        let read_value = hdp.injected_state.read_key(label, key5).unwrap();
        assert!(read_value == 5000, "Key5 should have value 5000");
        assert!(new_root != current_root, "Writing key5 should change root");
        current_root = new_root;

        // Verify all key-value pairs are correct
        let final_read_v1 = hdp.injected_state.read_key(label, key1).unwrap();
        let final_read_v2 = hdp.injected_state.read_key(label, key2).unwrap();
        let final_read_v3 = hdp.injected_state.read_key(label, key3).unwrap();
        let final_read_v4 = hdp.injected_state.read_key(label, key4).unwrap();
        let final_read_v5 = hdp.injected_state.read_key(label, key5).unwrap();

        assert!(final_read_v1 == 1000, "Final key1 should have value 1000");
        assert!(final_read_v2 == 2000, "Final key2 should have value 2000");
        assert!(final_read_v3 == 3000, "Final key3 should have value 3000");
        assert!(final_read_v4 == 4000, "Final key4 should have value 4000");
        assert!(final_read_v5 == 5000, "Final key5 should have value 5000");

        array![
            current_root, final_read_v1, final_read_v2, final_read_v3, final_read_v4, final_read_v5,
        ]
    }
}
