%builtins range_check
from starkware.cairo.common.alloc import alloc
from src.libs.utils import pow2alloc127, get_felt_bitlength

func main{range_check_ptr}() {
    alloc_locals;
    %{ print('\n') %}
    let pow2_array: felt* = pow2alloc127();
    assert pow2_array[0] = 1;
    assert pow2_array[127] = 2 ** 127;
    // assert pow2_array[128] = 2 ** 128;
    with pow2_array {
        let x = get_felt_bitlength(1);
        assert 0 = x - 1;
        let x = get_felt_bitlength(2 ** 127 - 1);
        assert 0 = x - 127;

        // let x = get_felt_bitlength(0);
        // let x = get_felt_bitlength(2**128);
    }
    return ();
}
