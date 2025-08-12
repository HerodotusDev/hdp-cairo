use std::process;

use clap::{Arg, Command};
use state_server::start_server;
use tracing::error;

#[tokio::main]
async fn main() {
    let matches = Command::new("HDP State Server")
        .version("0.1.0")
        .author("Herodotus Dev Ltd")
        .about("A stateful API server for managing HDP modules injected states")
        .arg(
            Arg::new("port")
                .short('p')
                .long("port")
                .value_name("PORT")
                .help("Sets the port number to listen on")
                .default_value("3000"),
        )
        .arg(
            Arg::new("host")
                .long("host")
                .value_name("HOST")
                .help("Sets the host address to bind to")
                .default_value("0.0.0.0"),
        )
        .get_matches();

    let port = matches.get_one::<String>("port").unwrap().parse::<u16>().unwrap_or_else(|_| {
        eprintln!("Invalid port number");
        process::exit(1);
    });

    let host = matches.get_one::<String>("host").unwrap();

    println!("Starting HDP State Server...");
    println!("Host: {}", host);
    println!("Port: {}", port);
    println!();
    println!("Available endpoints:");
    println!("  POST /new-trie - Create a new trie");
    println!("  POST /insert-initial-data - Insert initial data into a trie");
    println!("  GET /get-root-hash/{{trie_id}} - Get root hash of a trie");
    println!("  GET /get-key/{{trie_id}}?key=<key> - Get value of a key");
    println!("  GET /get-state-proofs - Generate structured StateProof objects for actions (read=inclusion|non-inclusion, write=update)");
    println!();

    if let Err(e) = start_server(port).await {
        error!("Server error: {}", e);
        process::exit(1);
    }
}
