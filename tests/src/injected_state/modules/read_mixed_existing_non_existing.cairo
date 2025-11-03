#[starknet::contract]
mod read_mixed_existing_non_existing {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'mixed_existing_non_existing';

        // Test reading a mix of existing and non-existing keys
        let existing_key = 0x123;
        let existing_value = 0x456;
        let non_existing_key = 0x789;

        // Write only one key
        let root = hdp.injected_state.write_key(label, existing_key, existing_value);

        // Read existing key
        let existing_read = hdp.injected_state.read_key(label, existing_key).unwrap();
        assert!(existing_read == existing_value, "Existing key should return its value");

        // Read non-existing key
        let non_existing_read = hdp.injected_state.read_key(label, non_existing_key);
        assert!(non_existing_read.is_none(), "Non-existing key should return None");

        // Test reading multiple keys in sequence (mix of existing and non-existing)
        let mixed_keys = array![existing_key, non_existing_key, 0x999, existing_key];
        let mut i = 0;
        loop {
            if i >= mixed_keys.len() {
                break;
            }
            let key = *mixed_keys.at(i);
            let value = hdp.injected_state.read_key(label, key);

            if key == existing_key {
                assert!(value.is_some(), "Existing key should return Some");
                let val = value.unwrap();
                assert!(val == existing_value, "Existing key should return correct value");
            } else {
                assert!(value.is_none(), "Non-existing key should return None");
            }

            i += 1;
        }

        array![root, existing_read]
    }
}
