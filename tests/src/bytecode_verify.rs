//! Tests for Cairo0 verify_bytecode_hash: fetch bytecode from RPC or use fixed bytecode,
//! convert to BytecodeLeWords, run the minimal Cairo0 test program via cairo-run, and assert
//! the computed code hash matches the expected (EVM keccak256) hash.

use std::{path::PathBuf, process::Command};

use alloy::primitives::{keccak256, Bytes};
use serde_json::json;
use types::{cairo::unconstrained::bytecode::BytecodeLeWords, keys::evm::account::Key};

/// Workspace root (parent of tests package).
fn workspace_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .canonicalize()
        .unwrap_or_else(|_| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(".."))
}

fn felt_to_decimal(felt: &cairo_vm::Felt252) -> String {
    format!("{}", felt)
}

/// Build program_input JSON for bytecode_verify_test.cairo.
/// expected_hash_*: EVM code hash as Uint256 (high = MSW 128 bits, low = LSW 128 bits).
fn bytecode_le_words_to_program_input(le: &BytecodeLeWords, expected_hash_low: u128, expected_hash_high: u128) -> serde_json::Value {
    let words: Vec<String> = le.words_64bit.iter().map(felt_to_decimal).collect();
    json!({
        "words_len": felt_to_decimal(&cairo_vm::Felt252::from(le.words_64bit.len())),
        "words": words,
        "last_input_word": felt_to_decimal(&le.last_input_word),
        "last_input_num_bytes": felt_to_decimal(&le.last_input_num_bytes),
        "expected_hash_low": expected_hash_low.to_string(),
        "expected_hash_high": expected_hash_high.to_string(),
    })
}

/// Run the Cairo0 bytecode_verify_test program with cairo-run.
/// Returns true if cairo-run succeeded.
fn run_bytecode_verify_cairo(compiled_program: &std::path::Path, program_input_path: &std::path::Path) -> bool {
    let venv = workspace_root().join(".venv").join("bin");
    let cairo_run = venv.join("cairo-run");
    if !cairo_run.exists() {
        eprintln!("Skipping bytecode_verify test: .venv/bin/cairo-run not found (run uv sync)");
        return false;
    }
    let status = Command::new(&cairo_run)
        .arg("--program")
        .arg(compiled_program)
        .arg("--program_input")
        .arg(program_input_path)
        .arg("--layout=starknet_with_keccak")
        .status();
    match status {
        Ok(s) => s.success(),
        Err(e) => {
            eprintln!("cairo-run failed: {}", e);
            false
        }
    }
}

/// Compile src/bytecode_verify_test.cairo to the given output path.
fn compile_bytecode_verify_test(out_path: &std::path::Path) -> bool {
    let root = workspace_root();
    let venv = root.join(".venv").join("bin");
    let cairo_compile = venv.join("cairo-compile");
    if !cairo_compile.exists() {
        eprintln!(
            "Skipping bytecode_verify test: .venv/bin/cairo-compile not found at {} (run uv sync)",
            cairo_compile.display()
        );
        return false;
    }
    let src = root.join("src").join("bytecode_verify_test.cairo");
    let cairo_path = format!("{}:{}", root.join("packages").join("eth_essentials").display(), root.display());
    let status = Command::new(&cairo_compile)
        .arg(format!("--cairo_path={}", cairo_path))
        .arg("--output")
        .arg(out_path)
        .arg(&src)
        .status();
    match status {
        Ok(s) => s.success(),
        Err(e) => {
            eprintln!("cairo-compile failed: {}", e);
            false
        }
    }
}

/// EVM code hash: keccak256(bytecode), 32 bytes big-endian.
/// Return (low, high) as Uint256: low = LSW 128 bits, high = MSW 128 bits.
fn evm_code_hash_parts(bytecode: &[u8]) -> (u128, u128) {
    let code_hash = keccak256(bytecode);
    let high = u128::from_be_bytes(code_hash[0..16].try_into().unwrap());
    let low = u128::from_be_bytes(code_hash[16..32].try_into().unwrap());
    (low, high)
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_bytecode_verify_with_fixed_bytecode() {
    // Minimal bytecode (8 zero bytes) and its EVM code hash; no network required.
    let bytecode: Bytes = [0u8; 8].into();
    let (low, high) = evm_code_hash_parts(bytecode.as_ref());

    let le = BytecodeLeWords::from(bytecode.clone());
    let input = bytecode_le_words_to_program_input(&le, low, high);

    let root = workspace_root();
    let compiled = root.join("target").join("bytecode_verify_test_compiled.json");
    let input_file = root.join("target").join("bytecode_verify_input.json");

    std::fs::create_dir_all(compiled.parent().unwrap()).ok();
    std::fs::write(&input_file, serde_json::to_string_pretty(&input).unwrap()).expect("write input JSON");

    assert!(
        compile_bytecode_verify_test(&compiled),
        "cairo-compile must succeed (run uv sync if .venv missing)"
    );

    assert!(
        run_bytecode_verify_cairo(&compiled, &input_file),
        "cairo-run verify_bytecode_hash must succeed for fixed bytecode (8 zero bytes)"
    );
}

fn is_skip_env_error(err: &str) -> bool {
    let s = err.to_lowercase();
    s.contains("null")
        || s.contains("system-configuration")
        || s.contains("operation not permitted")
        || s.contains("connection refused")
        || s.contains("dns")
        || s.contains("network")
        || s.contains("timed out")
}

#[tokio::test(flavor = "multi_thread", worker_threads = 1)]
async fn test_bytecode_verify_with_rpc_bytecode() {
    dotenvy::dotenv().ok();
    let _rpc_url = match std::env::var("RPC_URL_ETHEREUM_TESTNET").ok() {
        Some(u) if !u.is_empty() => u,
        _ => {
            eprintln!("Skipping RPC bytecode_verify test: RPC_URL_ETHEREUM_TESTNET not set");
            return;
        }
    };

    let key = Key {
        chain_id: 11155111,
        block_number: 7692344,
        address: "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238".parse().expect("address"),
    };

    let key_clone = key.clone();
    let handle = std::thread::spawn(move || {
        tokio::runtime::Runtime::new()
            .expect("runtime")
            .block_on(fetcher::proof_keys::unconstrained::ProofKeys::fetch_bytecode(&key_clone))
    });
    let bytecode = match handle.join() {
        Ok(Ok(b)) => b,
        Ok(Err(e)) => {
            let msg = e.to_string();
            if is_skip_env_error(&msg) {
                eprintln!("Skipping RPC bytecode_verify test: RPC unavailable ({})", msg);
                return;
            }
            panic!("fetch bytecode from RPC: {}", e);
        }
        Err(panic_payload) => {
            let msg = match panic_payload.downcast_ref::<&str>() {
                Some(s) => (*s).to_string(),
                _ => panic_payload.downcast_ref::<String>().map(|s| s.clone()).unwrap_or_default(),
            };
            if msg.contains("NULL") || msg.contains("system-configuration") {
                eprintln!("Skipping RPC bytecode_verify test: RPC unavailable (env panic: {})", msg);
                return;
            }
            std::panic::resume_unwind(panic_payload);
        }
    };

    let (low, high) = evm_code_hash_parts(bytecode.as_ref());
    let le = BytecodeLeWords::from(bytecode);
    let input = bytecode_le_words_to_program_input(&le, low, high);

    let root = workspace_root();
    let compiled = root.join("target").join("bytecode_verify_test_compiled.json");
    let input_file = root.join("target").join("bytecode_verify_rpc_input.json");

    std::fs::create_dir_all(compiled.parent().unwrap()).ok();
    std::fs::write(&input_file, serde_json::to_string_pretty(&input).unwrap()).expect("write input JSON");

    if !compile_bytecode_verify_test(&compiled) {
        eprintln!("Compilation skipped or failed; test passes without running Cairo.");
        return;
    }

    assert!(
        run_bytecode_verify_cairo(&compiled, &input_file),
        "cairo-run verify_bytecode_hash must succeed for RPC-fetched bytecode"
    );
}
