use core::keccak::keccak_u256s_be_inputs;

pub(crate) const POW_2_8: usize = 0x100;

/// Compute the three bloom filter indices for a given input.
/// The algorithm:
/// 1. Compute the Keccak256 hash of the input.
/// 2. For i in 0..3, take two consecutive bytes from the hash,
///    form a 16-bit integer, and then mask to keep only the lower 11 bits.
fn bloom_filter_indices(key: Span<u256>) -> (usize, usize, usize) {
    let hash: bytes31 = keccak_u256s_be_inputs(key).low.into();
    (
        ((hash[0].into() * POW_2_8) | hash[1].into()) & 0x07FF,
        ((hash[2].into() * POW_2_8) | hash[3].into()) & 0x07FF,
        ((hash[4].into() * POW_2_8) | hash[5].into()) & 0x07FF,
    )
}


/// Check if an element might be in the bloom filter.
/// Returns `true` if all three bits corresponding to the element are set.
pub fn contains(bloom: ByteArray, input: u256) -> bool {
    let (index1, index2, index3) = bloom_filter_indices(array![input].span());
    let pow_of_2: Array<u8> = array![0x1, 0x2, 0x4, 0x8, 0x10, 0x20, 0x40, 0x80];

    if (bloom[index1 / 8] & *pow_of_2[index1 % 8] == 0) {
        return false;
    }

    if (bloom[index2 / 8] & *pow_of_2[index2 % 8] == 0) {
        return false;
    }

    if (bloom[index3 / 8] & *pow_of_2[index3 % 8] == 0) {
        return false;
    }

    true
}
