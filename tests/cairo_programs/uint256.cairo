%builtins range_check

from starkware.cairo.common.alloc import alloc

from src.libs.utils import pow2alloc127, uint256_add
from starkware.cairo.common.uint256 import Uint256, uint256_mul
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint, bigint_to_uint256

func main{range_check_ptr}() {
    alloc_locals;
    let (xl, xh) = uint256_mul(Uint256(2 ** 127, 2 ** 126), Uint256(2 ** 127, 2 ** 126));
    let (xb) = uint256_to_bigint(xl);
    let (xlb) = bigint_to_uint256(xb);
    assert xlb = xl;
    return ();
}
