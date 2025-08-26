from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from src.memorizers.bare import BareMemorizer

namespace InjectedStatePackParams {
    func read(root_hash: felt, key_be: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = root_hash;
        assert params[1] = key_be;

        return (params=params, params_len=2);
    }
}

namespace InjectedStateHashParams {
    func read{poseidon_ptr: PoseidonBuiltin*}(root_hash: felt, key_be: felt) -> felt {
        let (params, params_len) = InjectedStatePackParams.read(
            root_hash=root_hash, key_be=key_be
        );
        return hash_memorizer_key(params, params_len);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

namespace InjectedStateMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{injected_state_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        key: felt, data: felt*
    ) {
        BareMemorizer.add{dict_ptr=injected_state_memorizer}(key, data);

        return ();
    }

    func get{injected_state_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt) -> (
        data: felt*
    ) {
        let (data) = BareMemorizer.get{dict_ptr=injected_state_memorizer}(key);
        return (data=data);
    }
}
