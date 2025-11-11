scarb build -p example_eth_call &&\
hdp dry-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output &&\
hdp fetch-proofs &&\
hdp sound-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output --proof_mode &&\
hdp sound-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output
