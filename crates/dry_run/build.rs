use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is not set")).join("../../");
    let python_path = workspace_root.join("venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let entrypoint_path = src_dir.join("contract_bootloader").join("contract_dry_run.cairo");
    let output_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set")).join("cairo");

    println!("cargo:rerun-if-changed={}", src_dir.display());

    // Check if DRY_RUN_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("DRY_RUN_COMPILED_JSON") {
        println!("cargo:rustc-env=DRY_RUN_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since DRY_RUN_COMPILED_JSON is already set.");
        return;
    }

    // Create output directory
    fs::create_dir_all(&output_dir).expect("Failed to create output directory");
    let output_file = output_dir.join("compiled.json");

    // Run the cairo-compile command.
    let status = Command::new(
        python_path
            .join("cairo-compile")
            .to_str()
            .expect("Failed to convert path to string"),
    )
    .arg(format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display()))
    .arg(entrypoint_path.to_str().expect("Failed to convert path to string"))
    .arg("--output")
    .arg(output_file.to_str().expect("Failed to convert path to string"))
    .status()
    .expect("Failed to execute cairo-compile");

    if !status.success() {
        panic!("cairo-compile failed for file: {}", entrypoint_path.display());
    }

    // This directive tells Cargo to set an environment variable named DRY_RUN_COMPILED_JSON
    // that will be available at compile-time (not runtime). The value is the path to our output file.
    // This environment variable can then be accessed in our Rust code using the env!() macro.
    // Example: let path = env!("DRY_RUN_COMPILED_JSON");
    println!("cargo:rustc-env=DRY_RUN_COMPILED_JSON={}", output_file.display());
}
