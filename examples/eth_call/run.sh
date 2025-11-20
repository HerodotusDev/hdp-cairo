scarb build -p example_eth_call &&\
hdp dry-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output &&\
hdp fetch-proofs --mmr-deployment-config examples/eth_call/mmr_deployment_config.json &&\
hdp sound-run -m target/dev/example_eth_call_module.compiled_contract_class.json --print_output --cairo_pie ./pie.zip
