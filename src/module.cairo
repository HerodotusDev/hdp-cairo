from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.types import ModuleTask
from starkware.cairo.common.alloc import alloc
from src.utils import word_reverse_endian_64

// Creates a Module from the input bytes
func init_module{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(input: felt*, input_bytes_len: felt) -> (res: ModuleTask) {
    alloc_locals;
    let (class_hash, module_inputs_len) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    let (module_inputs) = alloc();

    return (
            res=ModuleTask(
                class_hash=class_hash,
                module_inputs_len=module_inputs_len,
                module_inputs=module_inputs,
            ),
    );
}

// Decodes the constant parameters of the Module
// Inputs:
// input: le 8-byte chunks
// Outputs:
// class_hash, module_inputs_len
func extract_constant_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(input: felt*) -> (
    class_hash: felt, module_inputs_len: felt
) {
    alloc_locals;
    // ModuleTask Layout:
    // 0-3: class_hash
    // 4-7: dynamic_input_offset
    // 8-11: module_inputs_len

    // Copy class_hash
    let (class_hash_low_first) = word_reverse_endian_64([input]);
    %{
        print(f"class_hash_low_first = {ids.class_hash_low_first}")
    %}
    let (class_hash_low_second) = word_reverse_endian_64([input + 1]);
    %{
        print(f"class_hash_low_second = {ids.class_hash_low_second}")
    %}
    let (class_hash_high_first) = word_reverse_endian_64([input + 2]);
    %{
        print(f"class_hash_high_first = {ids.class_hash_high_first}")
    %}
    let (class_hash_high_second) = word_reverse_endian_64([input + 3]);
    %{
        print(f"class_hash_high_second = {ids.class_hash_high_second}")
    %}
    let class_hash_low = class_hash_low_first  * 0x10000000000000000 + class_hash_low_second;
    %{
        print(f"class_hash_low = {ids.class_hash_low}")
    %}
    let class_hash_high = class_hash_high_first * 0x10000000000000000 + class_hash_high_second ;
    %{
        print(f"class_hash_low = {ids.class_hash_high}")
    %}
    local class_hash: felt;
    %{
        class_hash = ids.class_hash_low * 2**128 + ids.class_hash_high
        print(f"class_hash = {class_hash}")
        ids.class_hash = class_hash
    %}

    assert [input + 8] = 0;  // first 3 chunks of increment should be 0
    let (module_inputs_len) = word_reverse_endian_64([input + 9]);

    return (
        class_hash=class_hash, module_inputs_len=module_inputs_len
    );
}