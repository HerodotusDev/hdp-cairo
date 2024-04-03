from starkware.cairo.common.uint256 import Uint256
from src.libs.utils import uint256_add

func compute_sum{range_check_ptr}(values: Uint256*, values_len: felt) -> Uint256 {
    if (values_len == 0) {
        return (Uint256(0, 0));
    }

    let sum_of_rest = compute_sum(values=values + Uint256.SIZE, values_len=values_len - 1);
    let (result, _carry) = uint256_add(values[0], sum_of_rest);

    return (result);
}
