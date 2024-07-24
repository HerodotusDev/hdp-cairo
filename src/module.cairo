from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.types import ModuleTask
from starkware.cairo.common.alloc import alloc
from src.utils import word_reverse_endian_64
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian


// Creates a Module from the input bytes
func init_module{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(input: felt*, input_bytes_len: felt) -> (res: ModuleTask) {
    alloc_locals;
    let (program_hash, module_inputs_len) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    %{ print(f"module_inputs_len = {ids.module_inputs_len}") %}

    let (module_inputs: Uint256*) = alloc();

    extract_dynamic_params{range_check_ptr=range_check_ptr}(
        encoded_module=input,
        module_inputs_len=module_inputs_len,
        index=0,
        extracted_inputs=module_inputs,
    );

    return (
        res=ModuleTask(
            program_hash=program_hash,
            module_inputs_len=module_inputs_len,
            module_inputs=module_inputs,
        ),
    );
}

// Decodes the constant parameters of the Module
// Inputs:
// input: le 8-byte chunks
// Outputs:
// program_hash, module_inputs_len
func extract_constant_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(input: felt*) -> (
    program_hash: Uint256, module_inputs_len: felt
) {
    alloc_locals;
    // ModuleTask Layout:
    // 0-3: program_hash
    // 4-7: dynamic_input_offset
    // 8-11: module_inputs_len

    // Copy program_hash
    let program_hash_le = Uint256(
            low=[input ] + [input + 1] * 0x10000000000000000,
            high=[input + 2] + [input + 3] * 0x10000000000000000,
        );
    let (program_hash) = uint256_reverse_endian(program_hash_le);

    // first 3 chunks of module_inputs_len should be 0
    assert [input + 8] = 0x0;
    assert [input + 9] = 0x0;
    assert [input + 10] = 0x0;
    let (module_inputs_len) = word_reverse_endian_64([input + 11]);

    return (program_hash=program_hash, module_inputs_len=module_inputs_len);
}

// Decodes the dynamic parameters of the Module
// Inputs:
// input: encoded_module, module_inputs_len
// Outputs:
// module_inputs
func extract_dynamic_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    encoded_module: felt*, module_inputs_len: felt, index: felt, extracted_inputs: Uint256*
) -> () {
    alloc_locals;
    // ModuleTask Layout:
    // 0-3: program_hash
    // 4-7: dynamic_input_offset
    // 8-11: module_inputs_len
    // 12-15: input 1...
    // 16-19: ...
    // ...

    if (module_inputs_len == index) {
        return ();
    }

    // Copy target_input
    let target_input_le = Uint256(
            low=[encoded_module + 12 + index * 4] + [encoded_module + 13 + index * 4] * 0x10000000000000000,
            high=[encoded_module + 14 + index * 4] + [encoded_module + 15 + index * 4] * 0x10000000000000000,
        );
    let (target_input) = uint256_reverse_endian(target_input_le);
    %{ print(f"input : {hex(ids.target_input.low + 2**128*ids.target_input.high)}") %}
    assert [extracted_inputs] = target_input;
  

    return extract_dynamic_params(
        encoded_module=encoded_module,
        module_inputs_len=module_inputs_len,
        index=index + 1,
        extracted_inputs=extracted_inputs + Uint256.SIZE,
    );
}
