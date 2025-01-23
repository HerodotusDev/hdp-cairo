use num_bigint::BigUint;
use num_traits::One;

pub mod debug;

pub fn count_leading_zero_nibbles_from_hex(hex_str: &str) -> u32 {
    let hex_str = hex_str.strip_prefix("0x").unwrap_or(hex_str);
    let count = hex_str.chars().take_while(|&c| c == '0').count() as u32;

    if hex_str.len() % 2 != 0 {
        return count + 1;
    }

    count

}

pub fn split_128(a: &BigUint) -> (BigUint, BigUint) {
    // Create a mask for the lower 128 bits: (1 << 128) - 1
    let mask = (&BigUint::one() << 128) - BigUint::one();
    let low = a & &mask; // lower 128 bits
    let high = a >> 128; // remaining higher bits

    (low, high)
}
