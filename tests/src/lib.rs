#![warn(unused_extern_crates)]
#![forbid(unsafe_code)]

#[cfg(test)]
pub mod evm;

#[cfg(test)]
pub mod starknet;

#[cfg(test)]
pub mod utils;

#[cfg(test)]
pub mod hashers;

#[cfg(test)]
pub mod injected_state;

#[cfg(test)]
pub mod test_state_server;

#[cfg(test)]
mod test_utils {
    use std::{env, path::PathBuf};

    use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
    use cairo_vm::{
        cairo_run::CairoRunConfig,
        types::{layout_name::LayoutName, program::Program},
        vm::runners::cairo_runner::{CairoRunner, RunnerMode},
    };
    use dry_hint_processor::syscall_handler::{evm, injected_state, starknet};
    use fetcher::{proof_keys::ProofKeys, Fetcher};
    use hints::vars;
    use syscall_handler::{SyscallHandler, SyscallHandlerWrapper};
    use tracing::debug;
    use types::{
        ChainProofs, HDPDryRunInput, HDPInput, InjectedState, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID, OPTIMISM_MAINNET_CHAIN_ID,
        OPTIMISM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
    };

    pub async fn run(compiled_class: CasmContractClass, injected_state: InjectedState) {
        // Init CairoRunConfig
        let cairo_run_config = CairoRunConfig {
            layout: LayoutName::all_cairo,
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
            injected_state: injected_state.clone(),
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
            cairo_run_config.disable_trace_padding,
        )
        .unwrap();

        // Init the Cairo VM
        let end = cairo_runner
            .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
            .unwrap();

        // Run the Cairo VM
        let mut hint_processor = dry_hint_processor::CustomHintProcessor::new(program_inputs);
        cairo_runner.run_until_pc(end, &mut hint_processor).unwrap();

        debug!("Dry run completed successfully.");

        let syscall_handler: SyscallHandler<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler> =
            cairo_runner
                .exec_scopes
                .get::<SyscallHandlerWrapper<evm::CallContractHandler, starknet::CallContractHandler, injected_state::CallContractHandler>>(
                    vars::scopes::SYSCALL_HANDLER,
                )
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
                evm::DryRunKey::Receipt(value) => {
                    proof_keys.evm.receipt_keys.insert(value);
                }
                evm::DryRunKey::Tx(value) => {
                    proof_keys.evm.transaction_keys.insert(value);
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

        // Add injected state keys
        for (root_hash, actions) in syscall_handler.call_contract_handler.injected_state_call_contract_handler.key_set {
            proof_keys.injected_state.insert(root_hash, actions);
        }

        let fetcher = Fetcher::new(&proof_keys);
        let (
            evm_proofs_mainnet,
            evm_proofs_sepolia,
            starknet_proofs_mainnet,
            starknet_proofs_sepolia,
            optimism_proofs_mainnet,
            optimism_proofs_sepolia,
            state_proofs,
        ) = tokio::try_join!(
            fetcher.collect_evm_proofs(ETHEREUM_MAINNET_CHAIN_ID),
            fetcher.collect_evm_proofs(ETHEREUM_TESTNET_CHAIN_ID),
            fetcher.collect_starknet_proofs(STARKNET_MAINNET_CHAIN_ID),
            fetcher.collect_starknet_proofs(STARKNET_TESTNET_CHAIN_ID),
            fetcher.collect_evm_proofs(OPTIMISM_MAINNET_CHAIN_ID),
            fetcher.collect_evm_proofs(OPTIMISM_TESTNET_CHAIN_ID),
            fetcher.collect_state_proofs(),
        )
        .unwrap();

        let program_inputs = HDPInput {
            chain_proofs: vec![
                ChainProofs::EthereumMainnet(evm_proofs_mainnet),
                ChainProofs::EthereumSepolia(evm_proofs_sepolia),
                ChainProofs::StarknetMainnet(starknet_proofs_mainnet),
                ChainProofs::StarknetSepolia(starknet_proofs_sepolia),
                ChainProofs::OptimismMainnet(optimism_proofs_mainnet),
                ChainProofs::OptimismSepolia(optimism_proofs_sepolia),
            ],
            params: vec![],
            compiled_class,
            state_proofs,
            injected_state: injected_state.clone(),
        };

        // Load the Program
        let program = Program::from_bytes(
            &std::fs::read(out_dir.join("cairo").join("sound_run_compiled.json")).unwrap(),
            Some(cairo_run_config.entrypoint),
        )
        .unwrap();

        // Init cairo runner
        let mut cairo_runner = CairoRunner::new_v2(
            &program,
            cairo_run_config.layout,
            None,
            runner_mode,
            cairo_run_config.trace_enabled,
            cairo_run_config.disable_trace_padding,
        )
        .unwrap();

        // Init the Cairo VM
        let end = cairo_runner
            .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
            .unwrap();

        // Run the Cairo VM
        let mut hint_processor = sound_hint_processor::CustomHintProcessor::new(program_inputs);
        cairo_runner.run_until_pc(end, &mut hint_processor).unwrap();

        debug!("Sound run completed successfully.");
    }
}
