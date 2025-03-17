#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod input;
pub mod output;
pub mod syscall_handler;

use std::{any::Any, collections::HashMap};

use ::syscall_handler::SyscallHandlerWrapper;
use cairo_lang_casm::{
    hints::{Hint, StarknetHint},
    operand::{BinOpOperand, DerefOrImmediate, Operation, Register, ResOperand},
};
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{BuiltinHintProcessor, HintProcessorData},
        cairo_1_hint_processor::hint_processor::Cairo1HintProcessor,
        hint_processor_definition::{HintExtension, HintProcessorLogic},
    },
    types::{exec_scope::ExecutionScopes, relocatable::Relocatable},
    vm::{errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker, vm_core::VirtualMachine},
    Felt252,
};
use hints::{extensive_hints, hints, vars, ExtensiveHintImpl, HintImpl};
use starknet_types_core::felt::Felt;
use syscall_handler::{evm, starknet};
use tokio::{runtime::Handle, task};
use types::HDPInput;

pub struct CustomHintProcessor {
    private_inputs: HDPInput,
    builtin_hint_proc: BuiltinHintProcessor,
    cairo1_builtin_hint_proc: Cairo1HintProcessor,
    hints: HashMap<String, HintImpl>,
    extensive_hints: HashMap<String, ExtensiveHintImpl>,
}

impl CustomHintProcessor {
    pub fn new(private_inputs: HDPInput) -> Self {
        Self {
            private_inputs,
            builtin_hint_proc: BuiltinHintProcessor::new_empty(),
            cairo1_builtin_hint_proc: Cairo1HintProcessor::new(Default::default(), Default::default(), true),
            hints: Self::hints(),
            extensive_hints: Self::extensive_hints(),
        }
    }

    #[rustfmt::skip]
    fn hints() -> HashMap<String, HintImpl> {
        let mut hints = hints();
        hints.insert(syscall_handler::ENTER_SCOPE_SYSCALL_HANDLER.into(), syscall_handler::enter_scope_syscall_handler);
        hints.insert(syscall_handler::SYSCALL_HANDLER_CREATE.into(), syscall_handler::syscall_handler_create);
        hints.insert(syscall_handler::SYSCALL_HANDLER_SET_SYSCALL_PTR.into(), syscall_handler::syscall_handler_set_syscall_ptr);
        hints
    }

    #[rustfmt::skip]
    fn extensive_hints() -> HashMap<String, ExtensiveHintImpl> {
        let hints = extensive_hints();
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

            let res = match hint_code {
                crate::input::HINT_INPUT => self.hint_input(vm, exec_scopes, hpd, constants),
                crate::output::HINT_OUTPUT => self.hint_output(vm, exec_scopes, hpd, constants),
                _ => Err(HintError::UnknownHint(hint_code.to_string().into_boxed_str())),
            };

            if !matches!(res, Err(HintError::UnknownHint(_))) {
                return res.map(|_| HintExtension::default());
            }

            if let Some(hint_impl) = self.hints.get(hint_code) {
                return hint_impl(vm, exec_scopes, hpd, constants).map(|_| HintExtension::default());
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
                let syscall_handler = exec_scopes
                    .get_mut_ref::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler>>(
                        vars::scopes::SYSCALL_HANDLER,
                    )?;
                return task::block_in_place(|| {
                    Handle::current().block_on(async {
                        syscall_handler
                            .execute_syscall(vm, syscall_ptr)
                            .await
                            .map(|_| HintExtension::default())
                    })
                });
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

fn get_ptr_from_res_operand(vm: &mut VirtualMachine, res: &ResOperand) -> Result<Relocatable, HintError> {
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
    (vm.get_relocatable(cell_reloc)? + &base_offset).map_err(|e| e.into())
}
