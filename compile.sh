cairo-compile --cairo_path=packages packages/contract_bootloader/contract_bootloader.cairo --output bootloader.json --proof_mode
cairo-run \
        --program=bootloader.json \
        --layout=starknet_with_keccak \
        --program_input=bootloader_input.json \
        --air_public_input=bootloader_public_input.json \
        --air_private_input=bootloader_private_input.json \
        --trace_file=bootloader.trace \
        --memory_file=bootloader.memory \
        --print_output \
        --proof_mode \
        --print_info