#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'alternating_patterns';

        // Test alternating between two keys
        let key1 = 0x111;
        let key2 = 0x222;
        let value1 = 0xAAA;
        let value2 = 0xBBB;

        let mut current_root = 0x0;

        // Write alternating pattern: key1, key2, key1, key2, key1
        // Write key1 (i=0, even)
        let new_root = hdp.injected_state.write_key(label, key1, value1);
        let read_value = hdp.injected_state.read_key(label, key1).unwrap();
        assert!(read_value == value1, "Value should match after write");
        current_root = new_root;

        // Write key2 (i=1, odd)
        let new_root = hdp.injected_state.write_key(label, key2, value2);
        let read_value = hdp.injected_state.read_key(label, key2).unwrap();
        assert!(read_value == value2, "Value should match after write");
        current_root = new_root;

        // Write key1 (i=2, even)
        let new_root = hdp.injected_state.write_key(label, key1, value1);
        let read_value = hdp.injected_state.read_key(label, key1).unwrap();
        assert!(read_value == value1, "Value should match after write");
        current_root = new_root;

        // Write key2 (i=3, odd)
        let new_root = hdp.injected_state.write_key(label, key2, value2);
        let read_value = hdp.injected_state.read_key(label, key2).unwrap();
        assert!(read_value == value2, "Value should match after write");
        current_root = new_root;

        // Write key1 (i=4, even)
        let new_root = hdp.injected_state.write_key(label, key1, value1);
        let read_value = hdp.injected_state.read_key(label, key1).unwrap();
        assert!(read_value == value1, "Value should match after write");
        current_root = new_root;

        // Verify both keys have their expected final values
        let read_v1 = hdp.injected_state.read_key(label, key1).unwrap();
        let read_v2 = hdp.injected_state.read_key(label, key2).unwrap();

        // Key1 should have value1 from last write (i=4, which is even, so key1)
        assert!(read_v1 == value1, "Key1 should have final value1");
        // Key2 should have value2 from last write (i=3, which is odd, so key2)
        assert!(read_v2 == value2, "Key2 should have final value2");

        array![current_root, read_v1, read_v2]
    }
}
