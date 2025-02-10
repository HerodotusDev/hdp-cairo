use alloy::{
    hex::FromHex,
    primitives::{keccak256, FixedBytes, U256},
};
use cairo_vm::Felt252;
use starknet_crypto::{pedersen_hash, poseidon_hash_many};

pub mod tests_runner;

#[tokio::test]
async fn test_poseidon_hash_rust() {
    let hash1 = poseidon_hash_many(&[Felt252::from(1), Felt252::from(2), Felt252::from(3), Felt252::from(4)]);
    let hash2 = poseidon_hash_many(&[Felt252::from(1), Felt252::from(2), Felt252::from(3), Felt252::from(5)]);

    assert!(hash1 == Felt252::from_hex("0x26e3ad8b876e02bc8a4fc43dad40a8f81a6384083cabffa190bcf40d512ae1d").unwrap());
    assert!(hash2 == Felt252::from_hex("0x57b091966b9a59d46d961b416376fadeb9b0755fabe4d3b63bed65a613c9f3f").unwrap());
}

#[tokio::test]
async fn test_keccak_hash_rust() {
    let values = vec![U256::from(1), U256::from(2), U256::from(3), U256::from(4)];
    let bytes: Vec<u8> = values.iter().flat_map(|v| v.to_be_bytes::<32>()).collect();
    let mut hash1 = keccak256(bytes.as_slice());
    hash1.reverse();

    assert!(hash1 == FixedBytes::from_hex("0x2d9982dfaf468a9ddf7101b6323aa9d56510e6fd534f267a01086462df912739").unwrap());

    let values2 = vec![U256::from(1), U256::from(2), U256::from(3), U256::from(5)];
    let bytes2: Vec<u8> = values2.iter().flat_map(|v| v.to_be_bytes::<32>()).collect();
    let mut hash2 = keccak256(bytes2.as_slice());
    hash2.reverse();

    assert!(hash2 == FixedBytes::from_hex("0x67cebf8d7d4a744b86437de146253d74fd06da9cd1a25494a707bd32c2d98bbd").unwrap());
}

#[tokio::test]
async fn test_perdersen_hash_rust() {
    let hash1 = pedersen_hash(&Felt252::from_bytes_le_slice(&[1]), &Felt252::from_bytes_le_slice(&[2]));
    let hash2 = pedersen_hash(&Felt252::from_bytes_le_slice(&[3]), &Felt252::from_bytes_le_slice(&[4]));

    assert!(hash1 == Felt252::from_hex("0x5bb9440e27889a364bcb678b1f679ecd1347acdedcbf36e83494f857cc58026").unwrap());
    assert!(hash2 == Felt252::from_hex("0x262697b88544f733e5c6907c3e1763131e9f14c51ee7951258abbfb29415fbf").unwrap());
}
