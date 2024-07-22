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

    %{
        print(f"module_inputs_len = {ids.module_inputs_len}")
    %}

    if (module_inputs_len == 0) {
        let (module_inputs) = alloc();
        return (
            res=ModuleTask(
                class_hash=class_hash,
                module_inputs_len=module_inputs_len,
                module_inputs=module_inputs,
            ),
        );
    } else {
        let (module_inputs) = alloc();
        extract_dynamic_params{
            range_check_ptr=range_check_ptr
        }(encoded_module=input, module_inputs_len=module_inputs_len, index=0, extracted_inputs=module_inputs);

        return (
            res=ModuleTask(
                class_hash=class_hash,
                module_inputs_len=module_inputs_len,
                module_inputs=module_inputs,
            ),
        );
    }

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
    // 0-4: class_hash
    // 4-8: dynamic_input_offset
    // 8-11: module_inputs_len

    // Copy class_hash
    let (class_hash_low_first) = word_reverse_endian_64([input]);
    let (class_hash_low_second) = word_reverse_endian_64([input + 1]);
    let (class_hash_high_first) = word_reverse_endian_64([input + 2]);
    let (class_hash_high_second) = word_reverse_endian_64([input + 3]);
    let class_hash_low = class_hash_low_first  * 0x10000000000000000 + class_hash_low_second;
    let class_hash_high = class_hash_high_first * 0x10000000000000000 + class_hash_high_second;
    let class_hash = class_hash_high * 0x100000000000000000000000000000000 + class_hash_high;

    // first 3 chunks of module_inputs_len should be 0
    assert [input + 8] = 0x0;
    assert [input + 9] = 0x0;
    assert [input + 10] = 0x0;
    let (module_inputs_len) = word_reverse_endian_64([input + 11]);

    return (
        class_hash=class_hash, module_inputs_len=module_inputs_len
    );
}

// Decodes the dynamic parameters of the Module
// Inputs:
// input: encoded_module, module_inputs_len
// Outputs:
// module_inputs
func extract_dynamic_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(encoded_module: felt*, module_inputs_len: felt, index: felt, extracted_inputs: felt*) -> () {
    alloc_locals;
    // ModuleTask Layout:
    // 0-4: class_hash
    // 4-8: dynamic_input_offset
    // 8-12: module_inputs_len
    // 12-16: input 1...
    // ...

    if (module_inputs_len == index) {
        return();
    }

    let (target_input_low_first) = word_reverse_endian_64([encoded_module + 12 + index*4]);
    let (target_input_low_second) = word_reverse_endian_64([encoded_module + 13 + index*4]);
    let (target_input_high_first) = word_reverse_endian_64([encoded_module + 14 + index*4]);
    let (target_input_high_second) = word_reverse_endian_64([encoded_module + 15 + index*4]);

    let target_input_low = target_input_low_first  * 0x10000000000000000 + target_input_low_second;
    let target_input_high = target_input_high_first * 0x10000000000000000 + target_input_high_second;
    let target_input = target_input_high * 0x100000000000000000000000000000000 + target_input_low;

    assert extracted_inputs[0] = target_input;

    return extract_dynamic_params(encoded_module=encoded_module, module_inputs_len=module_inputs_len, index=index+1, extracted_inputs=extracted_inputs+1);
}

