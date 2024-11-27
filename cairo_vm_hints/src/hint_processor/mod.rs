pub mod input;
pub mod output;

use crate::hints::{lib, vars};
use crate::syscall_handler::SyscallHandlerWrapper;
use cairo_lang_casm::{
    hints::{Hint, StarknetHint},
    operand::{BinOpOperand, DerefOrImmediate, Operation, Register, ResOperand},
};
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{
            BuiltinHintProcessor, HintProcessorData,
        },
        cairo_1_hint_processor::hint_processor::Cairo1HintProcessor,
        hint_processor_definition::{HintExtension, HintProcessorLogic},
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{
        errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker,
        vm_core::VirtualMachine,
    },
    Felt252,
};
use starknet_types_core::felt::Felt;
use std::{any::Any, collections::HashMap};

pub type HintImpl = fn(
    &mut VirtualMachine,
    &mut ExecutionScopes,
    &HintProcessorData,
    &HashMap<String, Felt252>,
) -> Result<(), HintError>;

/// Hint Extensions extend the current map of hints used by the VM.
/// This behaviour achieves what the `vm_load_data` primitive does for cairo-lang
/// and is needed to implement os hints like `vm_load_program`.
type ExtensiveHintImpl = fn(
    &mut VirtualMachine,
    &mut ExecutionScopes,
    &HintProcessorData,
    &HashMap<String, Felt252>,
) -> Result<HintExtension, HintError>;

pub struct CustomHintProcessor {
    private_inputs: serde_json::Value,
    builtin_hint_proc: BuiltinHintProcessor,
    cairo1_builtin_hint_proc: Cairo1HintProcessor,
    hints: HashMap<String, HintImpl>,
    extensive_hints: HashMap<String, ExtensiveHintImpl>,
}

impl Default for CustomHintProcessor {
    fn default() -> Self {
        Self::new(serde_json::Value::default())
    }
}

impl CustomHintProcessor {
    pub fn new(private_inputs: serde_json::Value) -> Self {
        Self {
            private_inputs,
            builtin_hint_proc: BuiltinHintProcessor::new_empty(),
            cairo1_builtin_hint_proc: Cairo1HintProcessor::new(
                Default::default(),
                Default::default(),
                true,
            ),
            hints: Self::hints(),
            extensive_hints: Self::extensive_hints(),
        }
    }

    #[rustfmt::skip]
    fn hints() -> HashMap<String, HintImpl> {
        let mut hints = HashMap::<String, HintImpl>::new();
        hints.insert(lib::contract_bootloader::contract_class::LOAD_CONTRACT_CLASS.into(), lib::contract_bootloader::contract_class::load_contract_class);
        hints.insert(lib::contract_bootloader::dict_manager::DICT_MANAGER_CREATE.into(), lib::contract_bootloader::dict_manager::dict_manager_create);
        hints.insert(lib::contract_bootloader::scopes::ENTER_SCOPE_SYSCALL_HANDLER.into(), lib::contract_bootloader::scopes::enter_scope_syscall_handler);
        hints.insert(lib::contract_bootloader::syscall_handler::SYSCALL_HANDLER_CREATE.into(), lib::contract_bootloader::syscall_handler::syscall_handler_create);
        hints.insert(lib::contract_bootloader::syscall_handler::SYSCALL_HANDLER_SET_SYSCALL_PTR.into(), lib::contract_bootloader::syscall_handler::syscall_handler_set_syscall_ptr);
        hints.insert(lib::decoder::evm::has_type_prefix::HINT_HAS_TYPE_PREFIX.into(), lib::decoder::evm::has_type_prefix::hint_has_type_prefix);
        hints.insert(lib::decoder::evm::is_byzantium::HINT_IS_BYZANTIUM.into(), lib::decoder::evm::is_byzantium::hint_is_byzantium);
        hints.insert(lib::decoder::evm::v_is_encoded::HINT_V_IS_ENCODED.into(), lib::decoder::evm::v_is_encoded::hint_v_is_encoded);
        hints.insert(lib::print::PROGRAM_HASH.into(), lib::print::program_hash);
        hints.insert(lib::segments::SEGMENTS_ADD.into(), lib::segments::segments_add);
        hints.insert(lib::segments::SEGMENTS_ADD_EVM_MEMORIZER_SEGMENT_INDEX.into(), lib::segments::segments_add_evm_memorizer_segment_index);
        hints.insert(lib::segments::SEGMENTS_ADD_EVM_MEMORIZER_OFFSET.into(), lib::segments::segments_add_evm_memorizer_offset);
        hints.insert(lib::segments::SEGMENTS_ADD_EVM_STARKNET_MEMORIZER_INDEX.into(), lib::segments::segments_add_evm_starknet_memorizer_index);
        hints.insert(lib::segments::SEGMENTS_ADD_STARKNET_MEMORIZER_OFFSET.into(), lib::segments::segments_add_starknet_memorizer_offset);
        hints
    }

    #[rustfmt::skip]
    fn extensive_hints() -> HashMap<String, ExtensiveHintImpl> {
        let mut hints = HashMap::<String, ExtensiveHintImpl>::new();
        hints.insert(crate::hints::lib::contract_bootloader::program::LOAD_PROGRAM.into(), crate::hints::lib::contract_bootloader::program::load_program);
        hints
    }
}

impl HintProcessorLogic for CustomHintProcessor {
    fn execute_hint(
        &mut self,
        _vm: &mut VirtualMachine,
        _exec_scopes: &mut ExecutionScopes,
        _hint_data: &Box<dyn Any>,
        _constants: &HashMap<String, Felt252>,
    ) -> Result<(), HintError> {
        unreachable!();
    }

    fn execute_hint_extensive(
        &mut self,
        vm: &mut VirtualMachine,
        exec_scopes: &mut ExecutionScopes,
        hint_data: &Box<dyn Any>,
        constants: &HashMap<String, Felt>,
    ) -> Result<HintExtension, HintError> {
        if let Some(hpd) = hint_data.downcast_ref::<HintProcessorData>() {
            let hint_code = hpd.code.as_str();
            if let Some(hint_impl) = self.hints.get(hint_code) {
                return hint_impl(vm, exec_scopes, hpd, constants)
                    .map(|_| HintExtension::default());
            }

            if let Some(hint_impl) = self.extensive_hints.get(hint_code) {
                let r = hint_impl(vm, exec_scopes, hpd, constants);
                return r;
            }

            return self
                .builtin_hint_proc
                .execute_hint(vm, exec_scopes, hint_data, constants)
                .map(|_| HintExtension::default());
        }

        if let Some(hint) = hint_data.downcast_ref::<Hint>() {
            if let Hint::Starknet(StarknetHint::SystemCall { system }) = hint {
                let syscall_ptr = get_ptr_from_res_operand(vm, system)?;
                // TODO: need to be generic here
                let syscall_handler =
                    exec_scopes.get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)?;

                return syscall_handler
                    .execute_syscall(vm, syscall_ptr)
                    .map(|_| HintExtension::default());
            } else {
                return self
                    .cairo1_builtin_hint_proc
                    .execute(vm, exec_scopes, hint)
                    .map(|_| HintExtension::default());
            }
        }

        Err(HintError::WrongHintData)
    }
}

impl ResourceTracker for CustomHintProcessor {}

fn get_ptr_from_res_operand(
    vm: &mut VirtualMachine,
    res: &ResOperand,
) -> Result<Relocatable, HintError> {
    let (cell, base_offset) = match res {
        ResOperand::Deref(cell) => (cell, Felt252::ZERO),
        ResOperand::BinOp(BinOpOperand {
            op: Operation::Add,
            a,
            b: DerefOrImmediate::Immediate(b),
        }) => (a, Felt252::from(&b.value)),
        _ => {
            return Err(HintError::CustomHint(
                "Failed to extract buffer, expected ResOperand of BinOp type to have Inmediate b value"
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
    (vm.get_relocatable(cell_reloc)? + &base_offset).map_err(|e| e.into())
}
