from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin

from src.hdp.hdp import run


func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local tests_len: felt;

    %{
        import os
        import json

        directory_path = 'tests/hdp/fixtures/'
        json_files = [file for file in os.listdir(directory_path) if file.endswith('.json')]
        data_list = []

        ids.tests_len = len(json_files)
        for json_file in json_files:
            file_path = os.path.join(directory_path, json_file)
            with open(file_path, 'r') as file:
                data = json.load(file)
                data_list.append(data)
    %}

    run_tests{
        output_ptr=output_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
    }(
        tests_len=tests_len,
        index=0
    );

    return ();
}


func run_tests{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}(tests_len: felt, index: felt) {


    if (tests_len == index){
        return ();
    }

    %{
        # Overwrite program input
        program_input = data_list[ids.index]
        print(f'Running test {ids.index + 1}/{ids.tests_len}')
    %}

    run{
        output_ptr=output_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
    }();

    return run_tests(
        tests_len=tests_len,
        index=index + 1
    );
}