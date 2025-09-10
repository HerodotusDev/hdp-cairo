#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'duplicate_keys_test';

        // Test reading the same key multiple times
        let key = 0x123;
        let value = 0x456;

        // Write the key
        let root = hdp.injected_state.write_key(label, key, value);

        // Read the same key multiple times and verify consistency
        let read1 = hdp.injected_state.read_key(label, key).unwrap();
        let read2 = hdp.injected_state.read_key(label, key).unwrap();
        let read3 = hdp.injected_state.read_key(label, key).unwrap();
        let read4 = hdp.injected_state.read_key(label, key).unwrap();

        // All reads should return the same value
        assert!(read1 == value, "First read should return correct value");
        assert!(read2 == value, "Second read should return correct value");
        assert!(read3 == value, "Third read should return correct value");
        assert!(read4 == value, "Fourth read should return correct value");

        // All reads should be equal to each other
        assert!(read1 == read2, "All reads should be equal");
        assert!(read2 == read3, "All reads should be equal");
        assert!(read3 == read4, "All reads should be equal");

        // Test reading duplicate keys in a loop
        let duplicate_keys = array![key, key, key, key];
        let mut i = 0;
        loop {
            if i >= duplicate_keys.len() {
                break;
            }
            let duplicate_key = *duplicate_keys.at(i);
            let duplicate_value = hdp.injected_state.read_key(label, duplicate_key).unwrap();
            assert!(duplicate_value == value, "Duplicate key read should return same value");
            i += 1;
        };

        array![root, read1, read2, read3, read4]
    }
}
