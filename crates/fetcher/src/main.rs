use clap::{Parser, ValueHint};
use fetcher::{parse_syscall_handler, Fetcher};
use std::{fs, path::PathBuf};
use types::ChainProofs;

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
struct Args {
    #[clap(value_parser, value_hint=ValueHint::FilePath)]
    filename: PathBuf,
    #[structopt(long = "program_output")]
    program_output: PathBuf,
}

#[tokio::main]
async fn main() -> Result<(), fetcher::FetcherError> {
    let args = Args::try_parse_from(std::env::args()).map_err(fetcher::FetcherError::Args)?;
    let input_file = fs::read(&args.filename)?;
    let proof_keys = parse_syscall_handler(&input_file)?;

    let fetcher = Fetcher::new(&proof_keys);
    let (evm_proofs, starknet_proofs) = tokio::try_join!(fetcher.collect_evm_proofs(), fetcher.collect_starknet_proofs())?;
    let chain_proofs = vec![ChainProofs::EthereumSepolia(evm_proofs), ChainProofs::StarknetSepolia(starknet_proofs)];

    fs::write(
        args.program_output,
        serde_json::to_string_pretty(&chain_proofs)
            .map_err(|e| fetcher::FetcherError::IO(e.into()))?
            .as_bytes(),
    )?;

    Ok(())
}
