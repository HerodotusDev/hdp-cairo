use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is not set")).join("../../");
    let python_path = workspace_root.join("venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let entrypoint_path = src_dir.join("hdp.cairo");
    let output_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set")).join("cairo");
    let hash_cache_file = output_dir.join("program_hash.txt");

    println!("cargo:rerun-if-changed={}", src_dir.display());

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

    // Computing the program_hash is super slow, so we want to make sure we only compute it when the output file has been modified.
    let should_compute_hash = if hash_cache_file.exists() {
        let cache_metadata = fs::metadata(&hash_cache_file).expect("Failed to get cache metadata");
        let output_metadata = fs::metadata(&output_file).expect("Failed to get output metadata");
        // Check if the output file has been modified since the last hash computation
        output_metadata.modified().expect("Failed to get modified time") > cache_metadata.modified().expect("Failed to get modified time")
    } else {
        true
    };

    let program_hash = if should_compute_hash {
        // Run cairo-hash-program to compute the program hash
        let hash_output = Command::new(python_path.join("cairo-hash-program"))
            .arg("--program")
            .arg(output_file.to_str().expect("Failed to convert path to string"))
            .output()
            .expect("Failed to execute cairo-hash-program");

        if !hash_output.status.success() {
            panic!("cairo-hash-program failed");
        }

        // Convert the output to a string and trim whitespace
        let hash = String::from_utf8(hash_output.stdout)
            .expect("Failed to parse program hash output")
            .trim()
            .to_string();

        // Cache the hash
        fs::write(&hash_cache_file, &hash).expect("Failed to write hash cache");

        hash
    } else {
        // Read the cached hash
        fs::read_to_string(&hash_cache_file).expect("Failed to read cached hash")
    };

    // Expose the program hash through a build directive
    println!("cargo:rustc-env=HDP_PROGRAM_HASH={}", program_hash);

    // This directive tells Cargo to set an environment variable named HDP_COMPILED_JSON
    // that will be available at compile-time (not runtime). The value is the path to our output file.
    // This environment variable can then be accessed in our Rust code using the env!() macro.
    // Example: let path = env!("HDP_COMPILED_JSON");
    println!("cargo:rustc-env=HDP_COMPILED_JSON={}", output_file.display());
}
