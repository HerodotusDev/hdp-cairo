from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_single, poseidon_hash, poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountState

const MEMORIZER_DEFAULT = 100000000; // An arbitrary large number. We need to ensure each memorizer never contains >= number of elements.

namespace HeaderMemorizer {
    func initialize{}() -> (header_dict: DictAccess*, header_dict_start: DictAccess*){
        let (header_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar header_dict_start = header_dict;

        return (header_dict=header_dict, header_dict_start=header_dict_start);
    }

    func add{
        poseidon_ptr: PoseidonBuiltin*,
        header_dict: DictAccess*,
    }(block_number: felt, index: felt){
        let key = gen_header_key(block_number);
        dict_write{dict_ptr=header_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        header_dict: DictAccess*,
        headers: Header*,
        poseidon_ptr: PoseidonBuiltin*,
    }(block_height: felt) -> (header: Header){
        let key = gen_header_key(block_height);
        let (index) = dict_read{dict_ptr=header_dict}(key);
        // ensure element exists
        // if(index == MEMORIZER_DEFAULT) {
        //     assert 1 = 0;
        // }
        
        return (header=headers[index]);
    }

    func exists{
        header_dict: DictAccess*,
        poseidon_ptr: PoseidonBuiltin*,
    }(block_height: felt) -> felt{
        let key = gen_header_key(block_height);
        let (index) = dict_read{dict_ptr=header_dict}(key);
        if(index != MEMORIZER_DEFAULT) {
            return 1;
        } else {
            return 0;
        }
    }
}

namespace AccountMemorizer {
    func initialize{}() -> (account_dict: DictAccess*, account_dict_start: DictAccess*){
        let (account_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar account_dict_start = account_dict;

        return (account_dict=account_dict, account_dict_start=account_dict_start);
    }

    func add{
        poseidon_ptr: PoseidonBuiltin*,
        account_dict: DictAccess*,
    }(address: felt*, block_number: felt, index: felt){
        let key = gen_account_key(address, block_number);
        dict_write{dict_ptr=account_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        account_dict: DictAccess*,
        account_states: AccountState*,
        poseidon_ptr: PoseidonBuiltin*,
    }(address: felt*, block_number: felt) -> (account_state: AccountState){
        let key = gen_account_key(address, block_number);
        let (index) = dict_read{dict_ptr=account_dict}(key);

        // // ensure element exists
        // if(index == MEMORIZER_DEFAULT) {
        //     assert 1 = 0;
        // }

        return (account_state=account_states[index]);
    }
}

// the account key is h(h(address), block_number). 
func gen_account_key{
    poseidon_ptr: PoseidonBuiltin*,
}(address: felt*, block_number: felt) -> felt{
    let (h_addr) = poseidon_hash_many(3, address);
    let (res) = poseidon_hash(h_addr, block_number);

    return res;
}

func gen_header_key{
    poseidon_ptr: PoseidonBuiltin*,
}(block_height: felt) -> felt{
    let (res) = poseidon_hash_single(block_height);
    return res;
}