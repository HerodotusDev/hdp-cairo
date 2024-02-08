from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak

func hash_n_addresses{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    addresses_64_little: felt**, keys_little: Uint256*, n_addresses: felt, index: felt
) {
    alloc_locals;
    if (index == n_addresses) {
        return ();
    } else {
        let (hash: Uint256) = keccak(addresses_64_little[index], 20);

        %{
            print(ids.hash.high)
            print(ids.hash.low)
        %}

        assert keys_little[index].low = hash.low;
        assert keys_little[index].high = hash.high;

        return hash_n_addresses(
            addresses_64_little=addresses_64_little,
            keys_little=keys_little,
            n_addresses=n_addresses,
            index=index + 1,
        );
    }
}