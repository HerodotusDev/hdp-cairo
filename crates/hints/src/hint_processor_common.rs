use cairo_lang_casm::operand::{BinOpOperand, DerefOrImmediate, Operation, Register, ResOperand};
use cairo_vm::{
    types::relocatable::Relocatable,
    vm::{errors::hint_errors::HintError, vm_core::VirtualMachine},
    Felt252,
};

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
