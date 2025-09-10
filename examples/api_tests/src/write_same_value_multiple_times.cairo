#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'same_value_multiple';
        let key = 0x123;
        let value = 0x456;

        // Test writing the same value multiple times
        let _write_count = 10;
        let mut current_root = 0x0;
        let mut root_history = ArrayTrait::new();

        // First write
        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after first write");
        assert!(new_root != current_root, "First write should change root");
        root_history.append(new_root);
        current_root = new_root;

        // Subsequent writes with same value (9 more times)
        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        let new_root = hdp.injected_state.write_key(label, key, value);
        let read_value = hdp.injected_state.read_key(label, key).unwrap();
        assert!(read_value == value, "Value should match after write");
        root_history.append(new_root);
        current_root = new_root;

        // Verify final value is correct
        let final_read = hdp.injected_state.read_key(label, key).unwrap();
        assert!(final_read == value, "Final value should match written value");

        array![current_root, final_read]
    }
}
