#![warn(unused_extern_crates)]
#![forbid(unsafe_code)]

#[cfg(test)]
pub mod evm;

#[cfg(test)]
pub mod starknet;

#[cfg(test)]
mod test_utils {
    use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
    use cairo_vm::{
        cairo_run::CairoRunConfig,
        types::{layout_name::LayoutName, program::Program},
        vm::runners::cairo_runner::{CairoRunner, RunnerMode},
    };
    use dry_hint_processor::syscall_handler::{evm, starknet, SyscallHandler, SyscallHandlerWrapper};
    use fetcher::{collect_evm_proofs, collect_starknet_proofs, proof_keys::ProofKeys, ProofProgress};
    use hints::vars;
    use std::{env, path::PathBuf};
    use types::{ChainProofs, HDPDryRunInput, HDPInput};

    pub async fn run(compiled_class: CasmContractClass) {
        // Init CairoRunConfig
        let cairo_run_config = CairoRunConfig {
            layout: LayoutName::starknet_with_keccak,
            relocate_mem: true,
            trace_enabled: true,
            ..Default::default()
        };

        let runner_mode = if cairo_run_config.proof_mode {
            RunnerMode::ProofModeCairo1
        } else {
            RunnerMode::ExecutionMode
        };

        // Locate the compiled program file in the `OUT_DIR` folder.
        let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set"));

        let program_inputs = HDPDryRunInput {
            params: vec![],
            compiled_class: compiled_class.clone(),
        };

        // Load the Program
        let program = Program::from_bytes(
            &std::fs::read(out_dir.join("cairo").join("dry_run_compiled.json")).unwrap(),
            Some(cairo_run_config.entrypoint),
        )
        .unwrap();

        // Init cairo runner
        let mut cairo_runner = CairoRunner::new_v2(
            &program,
            cairo_run_config.layout,
            None,
            runner_mode.clone(),
            cairo_run_config.trace_enabled,
        )
        .unwrap();

        // Init the Cairo VM
        let end = cairo_runner.initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false)).unwrap();

        // Run the Cairo VM
        let mut hint_processor = dry_hint_processor::CustomHintProcessor::new(program_inputs);
        cairo_runner.run_until_pc(end, &mut hint_processor).unwrap();

        let syscall_handler: SyscallHandler = cairo_runner
            .exec_scopes
            .get::<SyscallHandlerWrapper>(vars::scopes::SYSCALL_HANDLER)
            .unwrap()
            .syscall_handler
            .try_read()
            .unwrap()
            .clone();

        let mut proof_keys = ProofKeys::default();
        for key in syscall_handler.call_contract_handler.evm_call_contract_handler.key_set {
            match key {
                evm::DryRunKey::Account(value) => {
                    proof_keys.evm.account_keys.insert(value);
                }
                evm::DryRunKey::Header(value) => {
                    proof_keys.evm.header_keys.insert(value);
                }
                evm::DryRunKey::Storage(value) => {
                    proof_keys.evm.storage_keys.insert(value);
                }
            }
        }

        // Add Starknet keys
        for key in syscall_handler.call_contract_handler.starknet_call_contract_handler.key_set {
            match key {
                starknet::DryRunKey::Header(value) => proof_keys.starknet.header_keys.insert(value),
                starknet::DryRunKey::Storage(value) => proof_keys.starknet.storage_keys.insert(value),
            };
        }

        let progress = ProofProgress::new(&proof_keys, false);

        // Collect proofs using fetcher functions
        let (evm_proofs, starknet_proofs) = tokio::try_join!(
            collect_evm_proofs(&proof_keys.evm, &progress),
            collect_starknet_proofs(&proof_keys.starknet, &progress)
        )
        .unwrap();

        let program_inputs = HDPInput {
            chain_proofs: vec![ChainProofs::EthereumSepolia(evm_proofs), ChainProofs::StarknetSepolia(starknet_proofs)],
            params: vec![],
            compiled_class,
        };

        // Load the Program
        let program = Program::from_bytes(
            &std::fs::read(out_dir.join("cairo").join("sound_run_compiled.json")).unwrap(),
            Some(cairo_run_config.entrypoint),
        )
        .unwrap();

        // Init cairo runner
        let mut cairo_runner = CairoRunner::new_v2(&program, cairo_run_config.layout, None, runner_mode, cairo_run_config.trace_enabled).unwrap();

        // Init the Cairo VM
        let end = cairo_runner.initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false)).unwrap();

        // Run the Cairo VM
        let mut hint_processor = sound_hint_processor::CustomHintProcessor::new(program_inputs);
        cairo_runner.run_until_pc(end, &mut hint_processor).unwrap();
    }
}
