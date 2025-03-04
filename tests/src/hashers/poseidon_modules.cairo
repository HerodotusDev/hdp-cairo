#[starknet::contract]
mod hashers_poseidon {
    use core::hash::{HashStateTrait};
    use core::poseidon::{PoseidonImpl, poseidon_hash_span};
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let hash1 = poseidon_hash_span(array![1, 2, 3, 4].span());
        let mut hash1_alternative = PoseidonImpl::new()
            .update(1)
            .update(2)
            .update(3)
            .update(4)
            .finalize();
        let hash2 = poseidon_hash_span(array![1, 2, 3, 5].span());
        let mut hash2_alternative = PoseidonImpl::new()
            .update(1)
            .update(2)
            .update(3)
            .update(5)
            .finalize();

        assert!(hash1 == 0x26e3ad8b876e02bc8a4fc43dad40a8f81a6384083cabffa190bcf40d512ae1d);
        assert!(hash2 == 0x57b091966b9a59d46d961b416376fadeb9b0755fabe4d3b63bed65a613c9f3f);
        assert!(
            hash1_alternative == 0x26e3ad8b876e02bc8a4fc43dad40a8f81a6384083cabffa190bcf40d512ae1d,
        );
        assert!(
            hash2_alternative == 0x57b091966b9a59d46d961b416376fadeb9b0755fabe4d3b63bed65a613c9f3f,
        );
    }
}
