use std::{cmp::Ordering, collections::HashMap};

use cairo_vm::{
    hint_processor::builtin_hint_processor::{
        builtin_hint_processor_definition::HintProcessorData,
        hint_utils::{get_integer_from_var_name, insert_value_into_ap},
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

pub fn print_address_range(vm: &VirtualMachine, address: Relocatable, depth: usize, padding: Option<usize>) {
    let padding = padding.unwrap_or(0); // Default to 20 if not specified
    let start_offset = if address.offset >= padding { address.offset - padding } else { 0 };
    let end_offset = address.offset + depth + padding;

    println!("\nFull memory segment range for segment {}:", address.segment_index);
    println!("----------------------------------------");
    for i in start_offset..end_offset {
        let addr = Relocatable {
            segment_index: address.segment_index,
            offset: i,
        };
        match vm.get_maybe(&addr) {
            Some(value) => println!("Offset {}: {:?}", i, value),
            None => println!("Offset {}: <empty>", i),
        }
    }
    println!("----------------------------------------\n");
}

pub const HINT_RETRIEVE_OUTPUT: &str = r#"index = memory[ids.output_offsets_ptr+ids.i]
# print(f"Output {ids.i}/{ids.n} Index : {index}")
memory[ap] = 1 if ids.i == ids.n else 0"#;

pub fn hint_retrieve_output(
    vm: &mut VirtualMachine,
    _exec_scopes: &mut ExecutionScopes,
    hint_data: &HintProcessorData,
    _constants: &HashMap<String, Felt252>,
) -> Result<(), HintError> {
    let i = get_integer_from_var_name("i", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;
    let n = get_integer_from_var_name("n", vm, &hint_data.ids_data, &hint_data.ap_tracking)?;

    let insert = match (i - n).cmp(&Felt252::ZERO) {
        Ordering::Equal => Felt252::ONE,
        _ => Felt252::ZERO,
    };

    insert_value_into_ap(vm, insert)
}

// func retrieve_output{}(
//     values_segment: felt*, output_offsets_ptr: felt*, n: felt, continuous_output: felt
// ) -> (output: felt*) {
//     if (continuous_output != 0) {
//         let offset = output_offsets_ptr[0];
//         // %{ print(f"Continuous output! start value : {hex(memory[ids.values_segment + ids.offset])} Size: {ids.n//4}
// offset:{ids.offset}") %}         return (cast(values_segment + offset, felt*),);
//     }
//     alloc_locals;
//     let (local output: felt*) = alloc();
//     local one = 1;
//     local two = 2;
//     local three = 3;

//     tempvar i = 0;
//     tempvar output_offsets = output_offsets_ptr;

//     loop:
//     let i = [ap - 2];
//     let output_offsets = cast([ap - 1], felt*);
// %{
//     index = memory[ids.output_offsets_ptr+ids.i]
//     # print(f"Output {ids.i}/{ids.n} Index : {index}")
//     memory[ap] = 1 if ids.i == ids.n else 0
// %}
//     jmp end if [ap] != 0, ap++;

//     tempvar i_plus_one = i + one;
//     tempvar i_plus_two = i + two;
//     tempvar i_plus_three = i + three;

//     assert output[i] = values_segment[[output_offsets]];
//     assert output[i_plus_one] = values_segment[[output_offsets] + one];
//     assert output[i_plus_two] = values_segment[[output_offsets] + two];
//     assert output[i_plus_three] = values_segment[[output_offsets] + three];

//     [ap] = i + 4, ap++;
//     [ap] = output_offsets + 1, ap++;
//     jmp loop;

//     end:
//     assert i = n;
//     return (output=output);
// }
