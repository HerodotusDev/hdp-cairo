use std::{env, fs, path::PathBuf, process::Command};

fn run() -> Result<(), Box<dyn std::error::Error>> {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR")?).join("../../");
    let python_path = workspace_root.join(".venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let entrypoint_path = src_dir.join("hdp.cairo");
    let output_dir = PathBuf::from(env::var("OUT_DIR")?).join("cairo");

    println!("cargo:rerun-if-changed={}", src_dir.display());

    // Check if HDP_COMPILED_JSON is already set
    if let Ok(compiled_json) = env::var("HDP_COMPILED_JSON") {
        println!("cargo:rustc-env=HDP_COMPILED_JSON={}", compiled_json);
        println!("Skipping Cairo compilation since HDP_COMPILED_JSON is already set.");
        return Ok(());
    }

    // Create output directory
    fs::create_dir_all(&output_dir)?;
    let output_file = output_dir.join("compiled.json");

    // Run the cairo-compile command.
    let status = Command::new(python_path.join("cairo-compile"))
        .arg(format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display()))
        .arg(&entrypoint_path)
        .arg("--output")
        .arg(&output_file)
        .arg("--proof_mode")
        .status()?;

    if !status.success() {
        return Err(format!("cairo-compile failed for file: {}", entrypoint_path.display()).into());
    }

    // This directive tells Cargo to set an environment variable named HDP_COMPILED_JSON
    // that will be available at compile-time (not runtime). The value is the path to our output file.
    // This environment variable can then be accessed in our Rust code using the env!() macro.
    // Example: let path = env!("HDP_COMPILED_JSON");
    println!("cargo:rustc-env=HDP_COMPILED_JSON={}", output_file.display());
    Ok(())
}

fn main() {
    if let Err(err) = run() {
        eprintln!("sound_run build script error: {err}");
        std::process::exit(1);
    }
}
