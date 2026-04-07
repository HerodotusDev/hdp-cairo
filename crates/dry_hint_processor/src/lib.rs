#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
#![forbid(unsafe_code)]

pub mod input;
pub mod output;
pub mod syscall_handler;

use std::{any::Any, collections::HashMap};

use ::syscall_handler::SyscallHandlerWrapper;
use cairo_lang_casm::hints::{CoreHint, CoreHintBase, Hint, StarknetHint};
use cairo_vm::{
    hint_processor::{
        builtin_hint_processor::builtin_hint_processor_definition::{BuiltinHintProcessor, HintProcessorData},
        cairo_1_hint_processor::hint_processor::Cairo1HintProcessor,
        hint_processor_definition::{HintExtension, HintProcessorLogic},
    },
    types::exec_scope::ExecutionScopes,
    vm::{errors::hint_errors::HintError, runners::cairo_runner::ResourceTracker, vm_core::VirtualMachine},
    Felt252,
};
use hints::{
    extensive_hints,
    hint_processor_common::{get_ptr_from_res_operand, pretty_debug_text_from_vm_range},
    hints, vars, ExtensiveHintImpl, HintImpl,
};
use starknet_types_core::felt::Felt;
use syscall_handler::{evm, starknet};
use tokio::{runtime::Handle, task};
use tracing::trace;
use types::HDPDryRunInput;

use crate::syscall_handler::{injected_state, unconstrained};

/// Syscall handler type used by dry-run execution.
pub type DryRunSyscallHandler = ::syscall_handler::SyscallHandler<
    syscall_handler::evm::CallContractHandler,
    syscall_handler::starknet::CallContractHandler,
    injected_state::CallContractHandler,
    unconstrained::CallContractHandler,
>;

pub struct CustomHintProcessor {
    inputs: HDPDryRunInput,
    builtin_hint_proc: BuiltinHintProcessor,
    cairo1_builtin_hint_proc: Cairo1HintProcessor,
    hints: HashMap<String, HintImpl>,
    extensive_hints: HashMap<String, ExtensiveHintImpl>,
    pretty_output: bool,
}

impl CustomHintProcessor {
    pub fn new(inputs: HDPDryRunInput, pretty_output: bool) -> Self {
        Self {
            inputs,
            builtin_hint_proc: BuiltinHintProcessor::new_empty(),
            cairo1_builtin_hint_proc: Cairo1HintProcessor::new(Default::default(), Default::default(), true),
            hints: Self::hints(),
            extensive_hints: Self::extensive_hints(),
            pretty_output,
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
        Err(HintError::CustomHint(
            "Non-extensive hints are unsupported; enable extensive hints".into(),
        ))
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
            trace!(hint = hint_code, "Executing hint");

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
                let syscall_handler = exec_scopes.get_mut_ref::<SyscallHandlerWrapper<
                    evm::CallContractHandler,
                    starknet::CallContractHandler,
                    injected_state::CallContractHandler,
                    unconstrained::CallContractHandler,
                >>(vars::scopes::SYSCALL_HANDLER)?;
                return task::block_in_place(|| {
                    Handle::current().block_on(async {
                        syscall_handler
                            .execute_syscall(vm, syscall_ptr)
                            .await
                            .map(|_| HintExtension::default())
                    })
                });
            } else if self.pretty_output {
                if let Hint::Core(CoreHintBase::Core(CoreHint::DebugPrint { start, end })) = hint {
                    let text = pretty_debug_text_from_vm_range(vm, start, end)?;
                    if !text.is_empty() {
                        println!("{}", text);
                    }
                    return Ok(HintExtension::default());
                }
                return self
                    .cairo1_builtin_hint_proc
                    .execute(vm, exec_scopes, hint)
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
