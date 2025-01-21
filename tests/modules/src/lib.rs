#![allow(async_fn_in_trait)]
#![warn(unused_extern_crates)]
#![warn(unused_crate_dependencies)]
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
    use dry_hint_processor::syscall_handler::{evm, SyscallHandler, SyscallHandlerWrapper};
    use fetcher::proof_keys::{evm::ProofKeys as EvmProofKeys, ProofKeys};
    use futures::{FutureExt, StreamExt};
    use hints::vars;
    use std::{collections::HashSet, env, path::PathBuf};
    use types::{
        proofs::{self, header::HeaderMmrMeta},
        ChainProofs, HDPDryRunInput, HDPInput,
    };

    const BUFFER_UNORDERED: usize = 50;

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

        let mut headers_with_mmr: HashSet<HeaderMmrMeta<proofs::evm::header::Header>> = HashSet::default();

        let mut headers_with_mmr_fut = futures::stream::iter(
            proof_keys
                .evm
                .header_keys
                .iter()
                .map(|key| EvmProofKeys::fetch_header_proof(key.chain_id, key.block_number))
                .map(|f| f.boxed_local()),
        )
        .buffer_unordered(BUFFER_UNORDERED);

        while let Some(Ok(item)) = headers_with_mmr_fut.next().await {
            headers_with_mmr.insert(item);
        }

        let mut accounts: HashSet<proofs::evm::account::Account> = HashSet::default();

        let mut accounts_fut = futures::stream::iter(
            proof_keys
                .evm
                .account_keys
                .iter()
                .map(EvmProofKeys::fetch_account_proof)
                .map(|f| f.boxed_local()),
        )
        .buffer_unordered(BUFFER_UNORDERED);

        while let Some(Ok((header_with_mmr, account))) = accounts_fut.next().await {
            headers_with_mmr.insert(header_with_mmr);
            accounts.insert(account);
        }

        let mut storages: HashSet<proofs::evm::storage::Storage> = HashSet::default();

        let mut storages_fut = futures::stream::iter(
            proof_keys
                .evm
                .storage_keys
                .iter()
                .map(EvmProofKeys::fetch_storage_proof)
                .map(|f| f.boxed_local()),
        )
        .buffer_unordered(BUFFER_UNORDERED);

        while let Some(Ok((header_with_mmr, account, storage))) = storages_fut.next().await {
            headers_with_mmr.insert(header_with_mmr.clone());
            accounts.insert(account);
            storages.insert(storage);
        }

        let proofs = proofs::evm::Proofs {
            headers_with_mmr: headers_with_mmr.into_iter().collect(),
            accounts: accounts.into_iter().collect(),
            storages: storages.into_iter().collect(),
            ..Default::default()
        };

        let program_inputs = HDPInput {
            chain_proofs: vec![ChainProofs::EthereumSepolia(proofs)],
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
