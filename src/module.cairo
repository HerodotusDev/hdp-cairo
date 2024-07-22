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
        let (module_inputs) = extract_dynamic_params{
            range_check_ptr=range_check_ptr
        }(encoded_module=input,module_inputs_len=module_inputs_len);

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
    // 0-3: class_hash
    // 4-7: dynamic_input_offset
    // 8-11: module_inputs_len

    // Copy class_hash
    let (class_hash_low_first) = word_reverse_endian_64([input]);
    let (class_hash_low_second) = word_reverse_endian_64([input + 1]);
    let (class_hash_high_first) = word_reverse_endian_64([input + 2]);
    let (class_hash_high_second) = word_reverse_endian_64([input + 3]);
    let class_hash_low = class_hash_low_first  * 0x10000000000000000 + class_hash_low_second;
    let class_hash_high = class_hash_high_first * 0x10000000000000000 + class_hash_high_second ;
    local class_hash: felt;
    %{
        class_hash = ids.class_hash_low * 2**128 + ids.class_hash_high
        print(f"class_hash = {class_hash}")
        ids.class_hash = class_hash
    %}

    assert [input + 10] = 0;  // first 3 chunks of increment should be 0
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
func extract_dynamic_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(encoded_module: felt*, module_inputs_len: felt) -> (
    module_inputs: felt*
) {
    alloc_locals;
    // ModuleTask Layout:
    // 0-3: class_hash
    // 4-7: dynamic_input_offset
    // 8-11: module_inputs_len
    // 12-15: input 1 ... 
    // ...

    let (module_inputs) = alloc();

    tempvar i = 0;

    copy_loop:
    let i = [ap - 1];
    if (i == module_inputs_len) {
        jmp end_loop;
    }
   
    let offset = i * 4;
     %{
        print(f"offset = {ids.offset}")
        print(f"offset2 = {12+ ids.offset}")
    %}
    let (target_input_low_first) = word_reverse_endian_64([encoded_module + 12 + offset]);
    tempvar bitwise_ptr = bitwise_ptr + 3;
    let (target_input_low_second) = word_reverse_endian_64([encoded_module + 13 + offset]);
    tempvar bitwise_ptr = bitwise_ptr + 3;
    let (target_input_high_first) = word_reverse_endian_64([encoded_module + 14 + offset]);
    tempvar bitwise_ptr = bitwise_ptr + 3;
    let (target_input_high_second) = word_reverse_endian_64([encoded_module + 15 + offset]);

    let target_input_low = target_input_low_first  * 0x10000000000000000 + target_input_low_second;
    let target_input_high = target_input_high_first * 0x10000000000000000 + target_input_high_second ;
    local target_input: felt;
    %{
        target_input = ids.target_input_low * 2**128 + ids.target_input_high
        print(f"target_input = {target_input}")
        ids.target_input = target_input
    %}
    assert module_inputs[i] = target_input;
    [ap] = i + 1, ap++;

    jmp copy_loop;

    end_loop:

    return (
        module_inputs=module_inputs
    );
}

