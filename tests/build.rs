use std::{env, fs, path::PathBuf, process::Command};

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?).join("../");
    let python_path = workspace_root.join(".venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let output_dir = PathBuf::from(env::var("OUT_DIR")?).join("cairo");

    println!("cargo::rerun-if-changed={}", src_dir.display());

    let compiler = python_path.join("cairo-compile");
    let cairo_path_arg = format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display());

    // Check if DRY_RUN_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("DRY_RUN_COMPILED_JSON") {
        println!("cargo:rustc-env=DRY_RUN_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since DRY_RUN_COMPILED_JSON is already set.");
    } else {
        // Create output directory
        fs::create_dir_all(&output_dir)?;

        // Run the cairo-compile command.
        let entrypoint = src_dir.join("contract_bootloader").join("contract_dry_run.cairo");
        let output_file = output_dir.join("dry_run_compiled.json");
        let status = Command::new(&compiler)
            .arg(&cairo_path_arg)
            .arg(&entrypoint)
            .arg("--output")
            .arg(&output_file)
            .status()?;

        if !status.success() {
            return Err(format!("cairo-compile failed for file: {}", entrypoint.display()).into());
        }
    }

    // Check if HDP_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("HDP_COMPILED_JSON") {
        println!("cargo:rustc-env=HDP_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since HDP_COMPILED_JSON is already set.");
    } else {
        // Create output directory
        fs::create_dir_all(&output_dir)?;

        // Run the cairo-compile command.
        let entrypoint = src_dir.join("hdp.cairo");
        let output_file = output_dir.join("sound_run_compiled.json");
        let status = Command::new(&compiler)
            .arg(&cairo_path_arg)
            .arg(&entrypoint)
            .arg("--output")
            .arg(&output_file)
            .status()?;

        if !status.success() {
            return Err(format!("cairo-compile failed for file: {}", entrypoint.display()).into());
        }
    }
    Ok(())
}

fn main() {
    if let Err(err) = run() {
        eprintln!("tests build script error: {err}");
        std::process::exit(1);
    }
}
