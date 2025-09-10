#[starknet::contract]
mod module {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let label = 'edge_cases_test';

        // Test reading with zero key from empty trie
        let zero_key = 0x0;
        let zero_value = hdp.injected_state.read_key(label, zero_key);
        assert!(zero_value.is_none(), "Zero key should return None from empty trie");

        // Test reading with maximum key value from empty trie
        let max_key = 0x03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        let max_value = hdp.injected_state.read_key(label, max_key);
        assert!(max_value.is_none(), "Maximum key should return None from empty trie");

        // Now write some data and test edge cases with existing trie
        let test_key = 0x123;
        let test_value = 0x456;
        let root = hdp.injected_state.write_key(label, test_key, test_value);

        // Test reading zero key from non-empty trie
        let zero_value_from_non_empty = hdp.injected_state.read_key(label, zero_key);
        assert!(
            zero_value_from_non_empty.is_none(), "Zero key should return None from non-empty trie",
        );

        // Test reading max key from non-empty trie
        let max_value_from_non_empty = hdp.injected_state.read_key(label, max_key);
        assert!(
            max_value_from_non_empty.is_none(),
            "Maximum key should return None from non-empty trie",
        );

        // Test reading the actual written key
        let actual_value = hdp.injected_state.read_key(label, test_key).unwrap();
        assert!(actual_value == test_value, "Written key should return correct value");

        array![root, actual_value]
    }
}
