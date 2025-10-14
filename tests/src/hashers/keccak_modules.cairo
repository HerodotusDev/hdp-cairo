#[starknet::contract]
mod hashers_keccak {
    use core::keccak::{keccak_u256s_be_inputs};
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let hash1 = keccak_u256s_be_inputs(array![1,2,3,4].span());
        let hash2 = keccak_u256s_be_inputs(array![1,2,3,5].span());

        let hash3 = keccak_u256s_be_inputs(array![1].span());
        let hash4 = keccak_u256s_be_inputs(array![1,2].span());
        let hash5 = keccak_u256s_be_inputs(array![1,2,3].span());
        let hash6 = keccak_u256s_be_inputs(array![1,2,3,5,7].span());

       assert!(hash1 == 0x2d9982dfaf468a9ddf7101b6323aa9d56510e6fd534f267a01086462df912739);
       assert!(hash2 == 0x67cebf8d7d4a744b86437de146253d74fd06da9cd1a25494a707bd32c2d98bbd);
       assert!(hash3 == 0xf60cfab7e2cb9f2d73b0c2fa4a4bf40c326a7e71fdcdee263b071276522d0eb1);
       assert!(hash4 == 0xe0c2a7d2cc99d544061ac0ccbb083ac8976e54eed878fb1854dfe7b6ce7b0be9);
       assert!(hash5 == 0x9c94f221eddf185aa6e49f6a641a0944071b3f711f7bfe32d44bb20079620c6e);
       assert!(hash6 == 0xa2be4cfd50af371d37fab2814cb4fde068b498d9e24955560983c753139fa9a5);
    }
}
