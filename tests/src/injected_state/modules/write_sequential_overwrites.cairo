#[starknet::contract]
mod write_sequential_overwrites {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'sequential_overwrites';
        let key = 0x123;

        // Test multiple sequential overwrites of the same key
        let values = array![0x100, 0x200, 0x300, 0x400, 0x500];

        let mut current_root = 0x0;
        let mut root_history = ArrayTrait::new();

        // Perform sequential overwrites
        let mut i = 0;
        loop {
            if i >= values.len() {
                break;
            }

            let value = *values.at(i);
            let new_root = hdp.injected_state.write_key(label, key, value);

            // Verify the write
            let read_value = hdp.injected_state.read_key(label, key).unwrap();
            assert!(read_value == value, "Value should match after write");

            // Root should change for each overwrite
            assert!(new_root != current_root, "Overwrite should change root");

            root_history.append(new_root);
            current_root = new_root;
            i += 1;
        };

        // Verify all roots are unique
        let mut j = 0;
        loop {
            if j >= root_history.len() {
                break;
            }
            let mut k = j + 1;
            loop {
                if k >= root_history.len() {
                    break;
                }
                let root_j = *root_history.at(j);
                let root_k = *root_history.at(k);
                assert!(root_j != root_k, "Roots should be different");
                k += 1;
            };
            j += 1;
        };

        // Verify final value is correct
        // let final_value = hdp.injected_state.read_key(label, key).unwrap();
        // let expected_final = *values.at(values.len() - 1);
        // assert!(final_value == expected_final, "Final value should match last write");

        array![current_root]
    }
}
