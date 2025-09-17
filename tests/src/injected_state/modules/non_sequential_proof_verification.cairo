#[starknet::contract]
mod non_sequential_proof_verification {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'non_sequential_proof';
        let k1 = 0x1;
        let k2 = 0x2;
        let k3 = 0x3;
        let v1 = 0x100;
        let v2 = 0x200;
        let v3 = 0x300;

        // Build sequential states
        let r0 = 0x0;
        let r1 = hdp.injected_state.write_key(label, k1, v1);
        let r2 = hdp.injected_state.write_key(label, k2, v2);
        let r3 = hdp.injected_state.write_key(label, k3, v3);

        // Verify state transitions by reading back values
        // Verify k1 has v1
        let read_v1 = hdp.injected_state.read_key(label, k1).unwrap();
        assert!(read_v1 == v1, "k1 should have v1");

        // Verify k2 has v2
        let read_v2 = hdp.injected_state.read_key(label, k2).unwrap();
        assert!(read_v2 == v2, "k2 should have v2");

        // Verify k3 has v3
        let read_v3 = hdp.injected_state.read_key(label, k3).unwrap();
        assert!(read_v3 == v3, "k3 should have v3");

        // Verify all roots are different (state transitions)
        assert!(r1 != r0, "r1 should be different from r0");
        assert!(r2 != r1, "r2 should be different from r1");
        assert!(r3 != r2, "r3 should be different from r2");

        // Test reading all keys at final state
        let final_read_v1 = hdp.injected_state.read_key(label, k1).unwrap();
        let final_read_v2 = hdp.injected_state.read_key(label, k2).unwrap();
        let final_read_v3 = hdp.injected_state.read_key(label, k3).unwrap();

        assert!(final_read_v1 == v1, "Final k1 should have v1");
        assert!(final_read_v2 == v2, "Final k2 should have v2");
        assert!(final_read_v3 == v3, "Final k3 should have v3");

        array![r0, r1, r2, r3, final_read_v1, final_read_v2, final_read_v3]
    }
}
