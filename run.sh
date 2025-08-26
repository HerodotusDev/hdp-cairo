cargo run --release --bin dry_run -- -m target/dev/example_blacklist_module.compiled_contract_class.json --print_output --inputs examples/blacklist/input.json
cargo run --bin fetcher
cargo run --release --bin sound_run -- -m target/dev/example_blacklist_module.compiled_contract_class.json --print_output --inputs examples/blacklist/input.json --cairo_pie_output pie.zip


# MOST EVM
cargo run --release --bin dry_run -- -m /Users/kiki/Documents/HERODOTUS/MOST/hdp-modules/target/dev/custom_module_multi_evm_evm_get_storage.compiled_contract_class.json --print_output --inputs /Users/kiki/Documents/HERODOTUS/MOST/hdp-modules/tests/example_inputs_evm_optimism_mainnet.json


# MOST STARKNET
cargo run --release --bin dry_run -- -m /Users/kiki/Documents/HERODOTUS/MOST/hdp-modules/target/dev/custom_module_multi_evm_evm_get_storage.compiled_contract_class.json --print_output --inputs /Users/kiki/Documents/HERODOTUS/MOST/hdp-modules/tests/hdp_task_inputs_for_testing.json
