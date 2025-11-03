#[starknet::contract]
mod hashers_keccak {
    use core::keccak::{cairo_keccak, keccak_u256s_be_inputs};
    use hdp_cairo::HDP;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) {
        let hash1 = keccak_u256s_be_inputs(array![1, 2, 3, 4].span());
        let hash2 = keccak_u256s_be_inputs(array![1, 2, 3, 5].span());

        let hash3 = keccak_u256s_be_inputs(array![1].span());
        let hash4 = keccak_u256s_be_inputs(array![1, 2].span());
        let hash5 = keccak_u256s_be_inputs(array![1, 2, 3].span());
        let hash6 = keccak_u256s_be_inputs(array![1, 2, 3, 5, 7].span());

        assert!(hash1 == 0x2d9982dfaf468a9ddf7101b6323aa9d56510e6fd534f267a01086462df912739);
        assert!(hash2 == 0x67cebf8d7d4a744b86437de146253d74fd06da9cd1a25494a707bd32c2d98bbd);
        assert!(hash3 == 0xf60cfab7e2cb9f2d73b0c2fa4a4bf40c326a7e71fdcdee263b071276522d0eb1);
        assert!(hash4 == 0xe0c2a7d2cc99d544061ac0ccbb083ac8976e54eed878fb1854dfe7b6ce7b0be9);
        assert!(hash5 == 0x9c94f221eddf185aa6e49f6a641a0944071b3f711f7bfe32d44bb20079620c6e);
        assert!(hash6 == 0xa2be4cfd50af371d37fab2814cb4fde068b498d9e24955560983c753139fa9a5);

        // from
        // https://github.com/starkware-libs/cairo/blob/062b13af3c5748d05022e86d0e9d50fb449ecb2e/corelib/src/keccak.cairo#L142C1-L146C8
        // Hash "Hello world!" by splitting into 64-bit words in little-endian
        let mut input = array![0x6f77206f6c6c6548]; // a full 8-byte word
        let hash = cairo_keccak(ref input, 0x21646c72, 4); // 4 bytes of the last word
        assert!(hash == 0xabea1f2503529a21734e2077c8b584d7bee3f45550c2d2f12a198ea908e1d0ec);
    }
}
