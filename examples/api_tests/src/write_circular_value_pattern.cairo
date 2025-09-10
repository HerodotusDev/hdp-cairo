#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'circular_pattern';
        let key = 0x123;

        // Test writing a circular pattern of values
        let value1 = 0x100;
        let value2 = 0x200;
        let value3 = 0x300;
        let value4 = 0x100; // Back to first value
        let value5 = 0x200; // Back to second value

        let mut current_root = 0x0;
        let mut root_history = ArrayTrait::new();

        // Write value1
        let new_root = hdp.injected_state.write_key(label, key, value1);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value1, "Value1 should match after write");
        assert!(new_root != current_root, "Circular write 0 should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Write value2
        let new_root = hdp.injected_state.write_key(label, key, value2);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value2, "Value2 should match after write");
        assert!(new_root != current_root, "Circular write 1 should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Write value3
        let new_root = hdp.injected_state.write_key(label, key, value3);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value3, "Value3 should match after write");
        assert!(new_root != current_root, "Circular write 2 should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Write value4 (back to value1)
        let new_root = hdp.injected_state.write_key(label, key, value4);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value4, "Value4 should match after write");
        assert!(new_root != current_root, "Circular write 3 should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Write value5 (back to value2)
        let new_root = hdp.injected_state.write_key(label, key, value5);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value5, "Value5 should match after write");
        assert!(new_root != current_root, "Circular write 4 should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Verify final value is correct (should be value5 = value2)
        let final_read = hdp.injected_state.read_key(label, key).unwrap();
        assert!(final_read == value5, "Final value should match last write");

        array![current_root, final_read]
    }
}
