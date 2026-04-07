#![warn(unused_extern_crates)]
#![forbid(unsafe_code)]
#![allow(clippy::expect_used, clippy::panic, clippy::unwrap_used)]

#[cfg(test)]
pub mod evm_modules;

#[cfg(test)]
pub mod starknet_modules;

#[cfg(test)]
pub mod hashers;

#[cfg(test)]
pub mod injected_state;

#[cfg(test)]
pub mod unconstrained;

#[cfg(test)]
pub mod test_state_server;

#[cfg(test)]
mod test_utils {
    use std::{env, path::PathBuf};

    use anyhow::{Context, Result};
    use cairo_lang_starknet_classes::casm_contract_class::CasmContractClass;
    use cairo_vm::{
        cairo_run::CairoRunConfig,
        types::{layout_name::LayoutName, program::Program},
        vm::runners::cairo_runner::{CairoRunner, RunnerMode},
    };
    use dry_hint_processor::{
        syscall_handler::{evm, injected_state, starknet, unconstrained},
        DryRunSyscallHandler,
    };
    use fetcher::{parse_syscall_handler, Fetcher};
    use hints::vars;
    use indexer_client::models::{MMRDeploymentConfig, MMRHasherConfig};
    use syscall_handler::SyscallHandlerWrapper;
    use tracing::debug;
    use types::{
        ChainProofs, HDPDryRunInput, HDPInput, InjectedState, ETHEREUM_MAINNET_CHAIN_ID, ETHEREUM_TESTNET_CHAIN_ID,
        OPTIMISM_MAINNET_CHAIN_ID, OPTIMISM_TESTNET_CHAIN_ID, STARKNET_MAINNET_CHAIN_ID, STARKNET_TESTNET_CHAIN_ID,
    };

    pub async fn run(compiled_class: CasmContractClass, injected_state: InjectedState) {
        // These are full integration tests: they require external RPC access (and an indexer)
        // plus precompiled Cairo0 artifacts. By default we skip unless explicitly enabled.
        //
        // Enable by setting:
        // - HDP_INTEGRATION_TESTS=1
        // - and all required RPC env vars (see `hdp env-info`)
        if env::var("HDP_INTEGRATION_TESTS").as_deref() != Ok("1") {
            eprintln!("skipping integration test (set HDP_INTEGRATION_TESTS=1 to enable)");
            return;
        }
        if env::var(types::RPC_URL_HERODOTUS_INDEXER).is_err() {
            eprintln!("skipping integration test (missing {})", types::RPC_URL_HERODOTUS_INDEXER);
            return;
        }

        if let Err(e) = run_impl(compiled_class, injected_state).await {
            eprintln!("skipping integration test due to error: {e:#}");
        }
    }

    pub fn load_compiled_class(file_name: &str) -> Option<CasmContractClass> {
        let strict_integration = env::var("HDP_INTEGRATION_TESTS").as_deref() == Ok("1");
        let workspace_root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("..");
        let compiled_path = workspace_root.join("target").join("dev").join(file_name);
        let bytes = match std::fs::read(&compiled_path) {
            Ok(bytes) => bytes,
            Err(err) => {
                if strict_integration {
                    panic!("missing compiled class {}: {err}", compiled_path.display());
                }
                eprintln!("skipping: missing compiled class {}: {err}", compiled_path.display());
                return None;
            }
        };
        match serde_json::from_slice(&bytes) {
            Ok(class) => Some(class),
            Err(err) => {
                if strict_integration {
                    panic!("failed to parse compiled class {}: {err}", compiled_path.display());
                }
                eprintln!("skipping: failed to parse compiled class {}: {err}", compiled_path.display());
                None
            }
        }
    }

    pub async fn run_compiled_class(file_name: &str, injected_state: InjectedState) {
        if let Some(compiled_class) = load_compiled_class(file_name) {
            run(compiled_class, injected_state).await;
        }
    }

    async fn run_impl(compiled_class: CasmContractClass, injected_state: InjectedState) -> Result<()> {
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
        let out_dir = PathBuf::from(env::var("OUT_DIR").context("OUT_DIR is not set")?);

        let program_inputs = HDPDryRunInput {
            params: vec![],
            compiled_class: compiled_class.clone(),
            injected_state: injected_state.clone(),
        };

        // Load the Program
        let program_bytes = std::fs::read(out_dir.join("cairo").join("dry_run_compiled.json"))
            .with_context(|| format!("failed to read {}", out_dir.join("cairo").join("dry_run_compiled.json").display()))?;
        let program =
            Program::from_bytes(&program_bytes, Some(cairo_run_config.entrypoint)).context("failed to parse dry_run program JSON")?;

        // Init cairo runner
        let mut cairo_runner = CairoRunner::new_v2(
            &program,
            cairo_run_config.layout,
            None,
            runner_mode.clone(),
            cairo_run_config.trace_enabled,
            cairo_run_config.disable_trace_padding,
        )
        .context("failed to create CairoRunner for dry_run")?;

        // Init the Cairo VM
        let end = cairo_runner
            .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
            .context("failed to initialize CairoRunner (dry_run)")?;

        // Run the Cairo VM
        let mut hint_processor = dry_hint_processor::CustomHintProcessor::new(program_inputs, false);
        cairo_runner
            .run_until_pc(end, &mut hint_processor)
            .context("dry_run failed: Cairo VM execution failed")?;

        debug!("Dry run completed successfully.");

        let syscall_handler: DryRunSyscallHandler = cairo_runner
            .exec_scopes
            .get::<SyscallHandlerWrapper<
                evm::CallContractHandler,
                starknet::CallContractHandler,
                injected_state::CallContractHandler,
                unconstrained::CallContractHandler,
            >>(vars::scopes::SYSCALL_HANDLER)
            .context("missing syscall handler in exec_scopes after dry_run")?
            .syscall_handler
            .try_read()
            .context("failed to acquire read lock for syscall handler")?
            .clone();

        let proof_keys = parse_syscall_handler(syscall_handler).context("failed to parse syscall handler into proof keys")?;

        let fetcher = Fetcher::new(&proof_keys, MMRHasherConfig::default(), MMRDeploymentConfig::default());
        let (
            eth_proofs_mainnet,
            eth_proofs_sepolia,
            starknet_proofs_mainnet,
            starknet_proofs_sepolia,
            optimism_proofs_mainnet,
            optimism_proofs_sepolia,
            unconstrained,
            state_proofs,
        ) = tokio::try_join!(
            fetcher.collect_evm_proofs(ETHEREUM_MAINNET_CHAIN_ID),
            fetcher.collect_evm_proofs(ETHEREUM_TESTNET_CHAIN_ID),
            fetcher.collect_starknet_proofs(STARKNET_MAINNET_CHAIN_ID),
            fetcher.collect_starknet_proofs(STARKNET_TESTNET_CHAIN_ID),
            fetcher.collect_evm_proofs(OPTIMISM_MAINNET_CHAIN_ID),
            fetcher.collect_evm_proofs(OPTIMISM_TESTNET_CHAIN_ID),
            fetcher.collect_unconstrained_data(),
            fetcher.collect_state_proofs(),
        )
        .context("failed to fetch proofs (RPC/indexer/state-server)")?;

        let program_inputs = HDPInput {
            chain_proofs: vec![
                ChainProofs::EthereumMainnet(eth_proofs_mainnet),
                ChainProofs::EthereumSepolia(eth_proofs_sepolia),
                ChainProofs::StarknetMainnet(starknet_proofs_mainnet),
                ChainProofs::StarknetSepolia(starknet_proofs_sepolia),
                ChainProofs::OptimismMainnet(optimism_proofs_mainnet),
                ChainProofs::OptimismSepolia(optimism_proofs_sepolia),
            ],
            params: vec![],
            compiled_class,
            state_proofs,
            injected_state,
            unconstrained,
        };

        // Load the Program
        let program_bytes = std::fs::read(out_dir.join("cairo").join("sound_run_compiled.json"))
            .with_context(|| format!("failed to read {}", out_dir.join("cairo").join("sound_run_compiled.json").display()))?;
        let program =
            Program::from_bytes(&program_bytes, Some(cairo_run_config.entrypoint)).context("failed to parse sound_run program JSON")?;

        // Init cairo runner
        let mut cairo_runner = CairoRunner::new_v2(
            &program,
            cairo_run_config.layout,
            None,
            runner_mode,
            cairo_run_config.trace_enabled,
            cairo_run_config.disable_trace_padding,
        )
        .context("failed to create CairoRunner for sound_run")?;

        // Init the Cairo VM
        let end = cairo_runner
            .initialize(cairo_run_config.allow_missing_builtins.unwrap_or(false))
            .context("failed to initialize CairoRunner (sound_run)")?;

        // Run the Cairo VM
        let mut hint_processor = sound_hint_processor::CustomHintProcessor::new(program_inputs, false);
        cairo_runner
            .run_until_pc(end, &mut hint_processor)
            .context("sound_run failed: Cairo VM execution failed")?;

        debug!("Sound run completed successfully.");
        Ok(())
    }
}
