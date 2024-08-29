%builtins poseidon

from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash, poseidon_hash_many
from starkware.cairo.common.registers import get_label_location, get_ap
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.invoke import invoke

from src.memorizers.reader import MemorizerReader, MemorizerId
from src.memorizers.evm import EvmAccountMemorizer


func main{
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    // init memorizer
    let (dict_ptr, account_dict_start) = EvmAccountMemorizer.init();
    let memorizer_handler = MemorizerReader.init();
    // // write to memorizer
    EvmAccountMemorizer.add{
        account_dict=dict_ptr
    }(chain_id=0, block_number=1, address=2, rlp=new(1,2,3));

    // read from memorizer
    tempvar params = new(0, 1, 2);
    local params_len = 3;
    with dict_ptr, memorizer_handler {
        let (res, res_len) = MemorizerReader.read(0, MemorizerId.Account2, params);
    }

    %{ print("RLP_LEN", ids.res_len)%}

    // tempvar poseidon_ptr = poseidon_ptr + params_len * 4;

    return ();
}


// func main{
//     poseidon_ptr: PoseidonBuiltin*,
// }() {
//     alloc_locals;
//     let (local ptr2) = get_label_location(test_invoke2);
//     // local value = 10;

//     // // case 1:
//     // [ap] = value, ap++;
//     // call abs ptr2;
//     // let res = cast([ap - 1], felt);
//     // %{ print("res:", ids.res) %}

//     let value = 10;
//     // // case 2:
//     with value {
//         call abs ptr2;
//     }

//     let res2 = cast([ap - 1], felt);
//     %{ print("res2:", ids.res2) %}

//     return ();
// }


// func test_invoke2{
//     value: felt,
// }() -> felt {

//     return value + 10;
// }


// func main{
//     poseidon_ptr: PoseidonBuiltin*,
// }() {
//     alloc_locals;

//     tempvar invoke_params = cast(new(poseidon_ptr, 10, 20), felt*);
//     let (ptr) = get_label_location(test_invoke);

//     invoke(ptr, 3, invoke_params);
    
//     local res_len = [ap - 1];
//     local res = [ap - 2];
//     let poseidon_ptr = cast([ap - 3], PoseidonBuiltin*);
//     %{ print("res_len:", ids.res_len) %}
//     %{ print("res:", memory[ids.res]) %}
//     %{ print("res:", memory[ids.res + 1]) %}
//     %{ print("res:", memory[ids.res + 2]) %}

//     return ();

// }

// func test_invoke{
//     poseidon_ptr: PoseidonBuiltin*,
// }(a: felt, b: felt) -> (felt*, felt) {
//     let (arr: felt*) = alloc();
//     arr[0] = a;
//     arr[1] = b;
//     let (res) = poseidon_hash(a, b);
//     arr[2] = res;
//     return (arr, 3);
// }