use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{Read, Write};
use std::path::PathBuf;
use std::process::Command;
use std::{env, fs};

fn calculate_directory_hash(dir: &PathBuf) -> String {
    let mut hasher = Sha256::new();
    let mut entries: Vec<_> = fs::read_dir(dir)
        .unwrap()
        .filter_map(Result::ok)
        .filter(|entry| {
            let path = entry.path();
            path.is_file() && path.extension().map_or(false, |ext| ext == "cairo")
        })
        .collect();

    entries.sort_by_key(|entry| entry.path());

    for entry in entries {
        let path = entry.path();
        let mut file = File::open(&path).unwrap();
        let mut buffer = Vec::new();
        file.read_to_end(&mut buffer).unwrap();
        hasher.update(buffer);
    }

    format!("{:x}", hasher.finalize())
}

fn main() {
    let workspace_root = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is not set")).join("../../");
    let python_path = workspace_root.join("venv/bin");
    let cairo_path = workspace_root.join("packages/eth_essentials");
    let src_dir = workspace_root.join("src");
    let entrypoint_path = src_dir.join("contract_bootloader").join("contract_dry_run.cairo");
    let output_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is not set")).join("cairo");
    let checksum_file = output_dir.join("checksum.txt");

    // Calculate the current hash of the src directory
    let current_hash = calculate_directory_hash(&src_dir);

    // Check if recompilation is necessary
    if checksum_file.exists() {
        let mut previous_hash = String::new();
        File::open(&checksum_file)
            .expect("Failed to open checksum file")
            .read_to_string(&mut previous_hash)
            .expect("Failed to read checksum file");

        if previous_hash == current_hash {
            println!("No changes detected in src directory. Skipping compilation.");
            return;
        }
    }

    // Create output directory
    fs::create_dir_all(&output_dir).expect("Failed to create output directory");
    let output_file = output_dir.join("compiled.json");

    // Run the cairo-compile command.
    let status = Command::new(python_path.join("cairo-compile").to_str().expect("Failed to convert path to string"))
        .arg(format!("--cairo_path={}:{}", workspace_root.display(), cairo_path.display()))
        .arg(entrypoint_path.to_str().expect("Failed to convert path to string"))
        .arg("--output")
        .arg(output_file.to_str().expect("Failed to convert path to string"))
        .status()
        .expect("Failed to execute cairo-compile");

    if !status.success() {
        panic!("cairo-compile failed for file: {}", entrypoint_path.display());
    }

    // Save the new checksum
    File::create(&checksum_file)
        .expect("Failed to create checksum file")
        .write_all(current_hash.as_bytes())
        .expect("Failed to write checksum file");
}
