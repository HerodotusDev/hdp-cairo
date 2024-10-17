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
    func storage(chain_id: felt, block_number: felt, contract_address: felt, storage_address: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = contract_address;
        assert params[3] = storage_address;

        return (params=params, params_len=4);
    }
}

namespace StarknetHashParams {
    func header{poseidon_ptr: PoseidonBuiltin*}(chain_id: felt, block_number: felt) -> felt {
        let (params, params_len) = StarknetPackParams.header(
            chain_id=chain_id, block_number=block_number
        );
        return hash_memorizer_key(params, params_len);
    }

    func storage{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, contract_address: felt, storage_address: felt
    ) -> felt {
        let (params, params_len) = StarknetPackParams.storage(
            chain_id=chain_id, block_number=block_number, contract_address=contract_address, storage_address=storage_address
        );
        return hash_memorizer_key(params, params_len);
    }
}

namespace StarknetHashParams2 {
    func header{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, StarknetPackParams.HEADER_PARAMS_LEN);
    }

    func storage{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, StarknetPackParams.STORAGE_SLOT_PARAMS_LEN);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

namespace StarknetMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{starknet_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        key: felt, data: felt*
    ) {
        BareMemorizer.add{dict_ptr=starknet_memorizer}(key, data);

        return ();
    }

    func get{starknet_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt) -> (
        data: felt*
    ) {
        let (data) = BareMemorizer.get{dict_ptr=starknet_memorizer}(key);
        return (data=data);
    }
}
