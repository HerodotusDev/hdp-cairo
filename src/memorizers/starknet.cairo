from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from src.memorizers.bare import BareMemorizer, SingleBareMemorizer

namespace StarknetPackParams {
    const HEADER_PARAMS_LEN = 2;
    func header(chain_id: felt, block_number: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;

        return (params=params, params_len=2);
    }

    const STORAGE_SLOT_PARAMS_LEN = 4;
    func storage_slot(chain_id: felt, block_number: felt, contract_address: felt, storage_address: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = contract_address;
        assert params[3] = storage_address;

        return (params=params, params_len=4);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

namespace StarknetHeaderMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{starknet_header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, fields: felt*
    ) {
        let (params, params_len) = StarknetPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=starknet_header_dict}(key, fields);

        return ();
    }

    func get{starknet_header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> (
        fields: felt*
    ) {
        let key = hash_memorizer_key(params, StarknetPackParams.HEADER_PARAMS_LEN);
        let (fields) = BareMemorizer.get{dict_ptr=starknet_header_dict}(key);

        return (fields=fields);
    }

    func get2{starknet_header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt
    ) -> (fields: felt*) {
        let (params, params_len) = StarknetPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        let (fields) = BareMemorizer.get{dict_ptr=starknet_header_dict}(key);
        return (fields=fields);
    }
}

namespace StarknetStorageSlotMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return SingleBareMemorizer.init();
    }

    func add{starknet_storage_slot_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, contract_address: felt, storage_address: felt, value: felt
    ) {
        let (params, params_len) = StarknetPackParams.storage_slot(
            chain_id=chain_id, block_number=block_number, contract_address=contract_address, storage_address=storage_address
        );

        let key = hash_memorizer_key(params, params_len);
        SingleBareMemorizer.add{dict_ptr=starknet_storage_slot_dict}(key, value);

        return ();
    }

    func get{starknet_storage_slot_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> (
        value: felt
    ) {
        let key = hash_memorizer_key(params, StarknetPackParams.STORAGE_SLOT_PARAMS_LEN);
        let (value) = SingleBareMemorizer.get{dict_ptr=starknet_storage_slot_dict}(key);
        return (value=value);
    }

    func get2{starknet_storage_slot_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, contract_address: felt, storage_address: felt
    ) -> (value: felt) {
        let (params, params_len) = StarknetPackParams.storage_slot(
            chain_id=chain_id, block_number=block_number, contract_address=contract_address, storage_address=storage_address
        );

        let key = hash_memorizer_key(params, params_len);
        let (value) = SingleBareMemorizer.get{dict_ptr=starknet_storage_slot_dict}(key);
        return (value=value);
    }
}