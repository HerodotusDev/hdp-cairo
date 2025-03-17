cargo run --release --bin dry_run -- -m target/dev/example_blacklist_module.compiled_contract_class.json --print_output --inputs examples/blacklist/input.json
cargo run --bin fetcher
cargo run --release --bin sound_run -- -m target/dev/example_blacklist_module.compiled_contract_class.json --print_output --inputs examples/blacklist/input.json --cairo_pie_output pie.zip