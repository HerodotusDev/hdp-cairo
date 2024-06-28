// %builtins poseidon

from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_new
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import (
    poseidon_hash_single,
    poseidon_hash,
    poseidon_hash_many,
)
from starkware.cairo.common.dict import dict_write, dict_read
from src.types import Header, Transaction, Receipt
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize

namespace PackParams {
    func header(chain_id: felt, block_number: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;

        return (params=params, params_len=2);
    }

    func account(chain_id: felt, block_number: felt, address: felt*) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        memcpy(dst=params + 2, src=address, len=3);

        return (params=params, params_len=5);
    }

    func storage{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*
    ) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        memcpy(dst=params + 2, src=address, len=3);
        memcpy(dst=params + 5, src=storage_slot, len=4);

        %{
            print(memory[ids.params])
            print(memory[ids.params + 1])
            print(memory[ids.params + 2])
            print(memory[ids.params + 3])
            print(memory[ids.params + 4])
            print(memory[ids.params + 5])
            print(memory[ids.params + 6])
            print(memory[ids.params + 7])
            print(memory[ids.params + 8])
            print("______________________")
        
        %}

        return (params=params, params_len=9);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(
    params: felt*, params_len: felt
) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

namespace BareMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;

        let (local dict: DictAccess*) = default_dict_new(default_value=7);
        tempvar dict_start = dict;

        return (dict_ptr=dict, dict_ptr_start=dict_start);
    }

    func add{dict_ptr: DictAccess*}(key: felt, rlp: felt*) {
        dict_write(key=key, new_value=cast(rlp, felt));

        return ();
    }

    func get{dict_ptr: DictAccess*}(key: felt) -> (felt*,) {
        let (rlp: felt*) = dict_read(key=key);
        return (rlp=rlp);
    }
}

namespace HeaderMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, rlp: felt*
    ) {
        let (params, params_len) = PackParams.header(chain_id=chain_id, block_number=block_number);

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=header_dict}(key, rlp);

        return ();
    }

    func get{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.header(chain_id=chain_id, block_number=block_number);

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=header_dict}(key);
        return (rlp=rlp);
    }
}

namespace AccountMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{account_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*, rlp: felt*
    ) {
        let (params, params_len) = PackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=account_dict}(key, rlp);

        return ();
    }

    func get{account_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=account_dict}(key);
        return (rlp=rlp);
    }
}

namespace StorageMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{storage_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*, rlp: felt*
    ) {
        let (params, params_len) = PackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=storage_dict}(key, rlp);

        return ();
    }

    func get{storage_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let (test) = poseidon_hash_many(params_len, params);

        let (params, params_len) = PackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        %{
            print("StorageMemorizer::get")
            print(memory[ids.params])
            print(memory[ids.params + 1])
            print(memory[ids.params + 2])
            print(memory[ids.params + 3])
            print(memory[ids.params + 4])
            print(memory[ids.params + 5])
            print(memory[ids.params + 6])
            print(memory[ids.params + 7])
            print(memory[ids.params + 8])
            print("______________________")
        
        %}

        let key = hash_memorizer_key(params, params_len);
        %{ print("key:", ids.key) %}
        let (rlp) = BareMemorizer.get{dict_ptr=storage_dict}(key);
        return (rlp=rlp);
    }
}

// func main{poseidon_ptr: PoseidonBuiltin*}() {
//     let (rlp) = alloc();
//     %{
//         segments.write_arg(ids.rlp, [1,2,3,4])
//     %}

// let (header_dict, header_dict_start) = HeaderMemorizer.init();
//     HeaderMemorizer.add{
//         dict_ptr=header_dict,
//         poseidon_ptr=poseidon_ptr
//     }(
//         chain_id=1,
//         block_number=2,
//         rlp=rlp
//     );
//     let (res) = HeaderMemorizer.get{
//         dict_ptr=header_dict,
//         poseidon_ptr=poseidon_ptr
//     }(
//         chain_id=1,
//         block_number=2
//     );

// %{
//         print(memory[ids.res])
//         print(memory[ids.res + 1])
//         print(memory[ids.res + 2])
//         print(memory[ids.res + 3])

// %}

// return ();
// }
