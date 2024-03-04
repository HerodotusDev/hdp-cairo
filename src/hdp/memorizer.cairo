from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_single, poseidon_hash, poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountState
from starkware.cairo.common.uint256 import Uint256

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
        %{
            print("Add header to memorizer: ", ids.block_number, " -> ", ids.index)
        %}
        dict_write{dict_ptr=header_dict}(key=block_number, new_value=index);
        return ();
    }

    func get{
        header_dict: DictAccess*,
        headers: Header*,
        poseidon_ptr: PoseidonBuiltin*,
    }(block_number: felt) -> Header{
        let (index) = dict_read{dict_ptr=header_dict}(block_number);
        // ensure element exists
        // if(index == MEMORIZER_DEFAULT) {
        //     assert 1 = 0;
        // }
        %{
            print("get header to memorizer: ", ids.block_number, " -> ", ids.index)
        %}

        return (headers[index]);
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

        return (account_state=account_states[index]);
    }
}

namespace StorageMemorizer {
    func initialize{}() -> (storage_dict: DictAccess*, storage_dict_start: DictAccess*){
        let (storage_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar storage_dict_start = storage_dict;

        return (storage_dict=storage_dict, storage_dict_start=storage_dict_start);
    }

    func add{
        poseidon_ptr: PoseidonBuiltin*,
        storage_dict: DictAccess*,
    }(storage_slot: felt*, address: felt*, block_number: felt, index: felt){
        let key = gen_storage_key(storage_slot, address, block_number);

        dict_write{dict_ptr=storage_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        storage_dict: DictAccess*,
        storage_items: Uint256*,
        poseidon_ptr: PoseidonBuiltin*,
    }(storage_slot: felt*, address: felt*, block_number: felt) -> (storage_item: Uint256){
        let key = gen_storage_key(storage_slot, address, block_number);

        let (index) = dict_read{dict_ptr=storage_dict}(key);


        return (storage_item=storage_items[index]);
    }
}

// the account key is h(slot.key, account_key). 
func gen_storage_key{
    poseidon_ptr: PoseidonBuiltin*,
}(storage_slot: felt*, address: felt*, block_number: felt) -> felt{
    alloc_locals;

    let account_key = gen_account_key(address, block_number);
    let (h_key) = poseidon_hash_many(4, storage_slot);
    let (res) = poseidon_hash(h_key, account_key);

    return res;
}

// the account key is h(h(address), block_number). 
func gen_account_key{
    poseidon_ptr: PoseidonBuiltin*,
}(address: felt*, block_number: felt) -> felt{
    let (h_addr) = poseidon_hash_many(3, address);
    let (res) = poseidon_hash(h_addr, block_number);

    return res;
}