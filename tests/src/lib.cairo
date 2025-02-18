pub mod evm;
pub mod hashers;
pub mod starknet;
pub mod utils;

use alexandria_bytes::utils::{BytesDebug, BytesDisplay};
use alexandria_bytes::{Bytes, BytesTrait};
use alexandria_encoding::sol_abi::{decode::SolAbiDecodeTrait, sol_bytes::SolBytesTrait};
use core::starknet::{ContractAddress, EthAddress};

fn sol_abi_decode_test() {
    let encoded: Bytes = BytesTrait::new(
        384,
        array![
            0x00000000000000000000000000000000,
            0x0000000000000000000000000000a0a1,
            0x00000000000000000000000000000000,
            0x000000000000000000000000a2a3a4a5,
            0x00000000000000000000000000000000,
            0x000000000000000000000000000000a6,
            0x00000000000000000000000000000000,
            0xa7a8a9aaabacadaeafb0b1b2b3b4b5b6,
            0xabcdefabcdefabcdefabcdefabcdefab,
            0xcdefabcdefabcdefabcdefabcdefabcd,
            0x00000000000000000000000000000000,
            0x0000000000000000b7b8b9babbbcbdbe,
            0x00a0a1a2a30000000000000000000000,
            0x00000000000000000000000000000000,
            0xa0a1a2a3a4a5a6a7a8a9aaabacadaeaf,
            0xb0b1b2b3000000000000000000000000,
            0x000000000000000000000000000000a0,
            0xaaab00000000000000000000000000ac,
            0x00000000000000000000000000000000,
            0x00000000000000000000000000001234,
            0x00a0a1a2a30000000000000000000000,
            0x00000000000000000000000000001234,
            0x000000000000000000000000Deadbeef,
            0xDeaDbeefdEAdbeefdEadbEEFdeadbeEF,
        ],
    );

    let mut offset = 0;
    let decoded: u16 = encoded.decode(ref offset);
    assert!(decoded == 0xa0a1);
    assert!(offset == 32);

    let decoded: u32 = encoded.decode(ref offset);
    assert!(decoded == 0xa2a3a4a5);
    assert!(offset == 64);

    let decoded: u8 = encoded.decode(ref offset);
    assert!(decoded == 0xa6);
    assert!(offset == 96);

    let decoded: u128 = encoded.decode(ref offset);
    assert!(decoded == 0xa7a8a9aaabacadaeafb0b1b2b3b4b5b6);
    assert!(offset == 128);

    let decoded: u256 = encoded.decode(ref offset);
    assert!(
        decoded == 0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd_u256,
        "Decode uint256 failed",
    );
    assert!(offset == 160);

    let decoded: u64 = encoded.decode(ref offset);
    assert!(decoded == 0xb7b8b9babbbcbdbe);
    assert!(offset == 192);

    let decoded: Bytes = SolBytesTrait::<Bytes>::bytes5(encoded.decode(ref offset));
    assert!(decoded == SolBytesTrait::bytes5(0xa0a1a2a3));
    assert!(offset == 224);

    let decoded: ByteArray = encoded.decode(ref offset);
    let expected: ByteArray = SolBytesTrait::bytes32(
        0xa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3000000000000000000000000_u256,
    )
        .into();
    assert!(decoded == expected);
    assert!(offset == 256);

    let decoded: bytes31 = encoded.decode(ref offset);
    let bytes_31: bytes31 = 0xa0aaab00000000000000000000000000ac.try_into().unwrap();
    assert!(decoded == bytes_31, "Decode byte31 failed");
    assert!(offset == 288);

    let decoded: felt252 = encoded.decode(ref offset);
    assert!(decoded == 0x1234_felt252);
    assert!(offset == 320);

    let expected: ContractAddress =
        0xa0a1a2a3000000000000000000000000000000000000000000000000001234_felt252
        .try_into()
        .expect('Couldn\'t convert to address');
    let decoded: ContractAddress = encoded.decode(ref offset);
    assert!(decoded == expected);
    assert!(offset == 352);

    let expected: EthAddress = 0xDeadbeefDeaDbeefdEAdbeefdEadbEEFdeadbeEF_u256.into();
    let decoded: EthAddress = encoded.decode(ref offset);
    assert!(decoded == expected);
    assert!(offset == 384);
}
