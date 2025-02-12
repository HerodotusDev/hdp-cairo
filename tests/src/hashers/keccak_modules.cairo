#[starknet::contract]
mod hashers_keccak {
    use core::keccak::{keccak_u256s_be_inputs};
    use hdp_cairo::{HDP};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let hash1 = keccak_u256s_be_inputs(array![1, 2, 3, 4].span());
        let hash2 = keccak_u256s_be_inputs(array![1, 2, 3, 5].span());

        assert!(hash1 == 0x2d9982dfaf468a9ddf7101b6323aa9d56510e6fd534f267a01086462df912739);
        assert!(hash2 == 0x67cebf8d7d4a744b86437de146253d74fd06da9cd1a25494a707bd32c2d98bbd);
    }
}
