use cairo_lang_casm::operand::{BinOpOperand, DerefOrImmediate, Operation, Register, ResOperand};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};
use types::pretty_debug::pretty_debug_text;

pub fn get_ptr_from_res_operand(vm: &mut VirtualMachine, res: &ResOperand) -> Result<Relocatable, HintError> {
    let (cell, base_offset) = match res {
        ResOperand::Deref(cell) => (cell, Felt252::ZERO),
        ResOperand::BinOp(BinOpOperand {
            op: Operation::Add,
            a,
            b: DerefOrImmediate::Immediate(b),
        }) => (a, Felt252::from(&b.value)),
        _ => {
            return Err(HintError::CustomHint(
                "Failed to extract buffer, expected ResOperand of BinOp type to have Immediate b value"
                    .to_owned()
                    .into_boxed_str(),
            ));
        }
    };
    let base = match cell.register {
        Register::AP => vm.get_ap(),
        Register::FP => vm.get_fp(),
    };
    let cell_reloc = (base + (i32::from(cell.offset)))?;
    (vm.get_relocatable(cell_reloc)? + &base_offset).map_err(Into::into)
}

/// Reads felts in the VM range `[start, end)` and decodes them as Cairo short-string debug output.
pub fn pretty_debug_text_from_vm_range(
    vm: &mut VirtualMachine,
    start: &ResOperand,
    end: &ResOperand,
) -> Result<String, HintError> {
    let start_ptr = get_ptr_from_res_operand(vm, start)?;
    let end_ptr = get_ptr_from_res_operand(vm, end)?;
    let len = (end_ptr - start_ptr).map_err(|_| HintError::CustomHint("DebugPrint: invalid range".into()))?;
    if len == 0 {
        return Ok(String::new());
    }
    let felts: Vec<Felt252> = vm
        .get_integer_range(start_ptr, len)?
        .into_iter()
        .map(|f| (*f.as_ref()))
        .collect();
    Ok(pretty_debug_text(&felts))
}
