use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is not set")).join("../");
    let python_path = workspace_root.join("venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let output_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set")).join("cairo");

    println!("cargo::rerun-if-changed={}", src_dir.display());

    // Check if DRY_RUN_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("DRY_RUN_COMPILED_JSON") {
        println!("cargo:rustc-env=DRY_RUN_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since DRY_RUN_COMPILED_JSON is already set.");
    } else {
        // Create output directory
        fs::create_dir_all(&output_dir).expect("Failed to create output directory");

        // Run the cairo-compile command.
        let status = Command::new(
            python_path
                .join("cairo-compile")
                .to_str()
                .expect("Failed to convert path to string"),
        )
        .arg(format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display()))
        .arg(
            src_dir
                .join("contract_bootloader")
                .join("contract_dry_run.cairo")
                .to_str()
                .expect("Failed to convert path to string"),
        )
        .arg("--output")
        .arg(
            output_dir
                .join("dry_run_compiled.json")
                .to_str()
                .expect("Failed to convert path to string"),
        )
        .status()
        .expect("Failed to execute cairo-compile");

        if !status.success() {
            panic!(
                "cairo-compile failed for file: {}",
                src_dir.join("contract_bootloader").join("contract_dry_run.cairo").display()
            );
        }
    }

    // Check if HDP_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("HDP_COMPILED_JSON") {
        println!("cargo:rustc-env=HDP_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since HDP_COMPILED_JSON is already set.");
    } else {
        // Create output directory
        fs::create_dir_all(&output_dir).expect("Failed to create output directory");

        // Run the cairo-compile command.
        let status = Command::new(
            python_path
                .join("cairo-compile")
                .to_str()
                .expect("Failed to convert path to string"),
        )
        .arg(format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display()))
        .arg(src_dir.join("hdp.cairo").to_str().expect("Failed to convert path to string"))
        .arg("--output")
        .arg(
            output_dir
                .join("sound_run_compiled.json")
                .to_str()
                .expect("Failed to convert path to string"),
        )
        .status()
        .expect("Failed to execute cairo-compile");

        if !status.success() {
            panic!("cairo-compile failed for file: {}", src_dir.join("hdp.cairo").display());
        }
    }
}
