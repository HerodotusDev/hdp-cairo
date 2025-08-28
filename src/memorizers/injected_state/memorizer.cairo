from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from src.memorizers.bare import BareMemorizer

namespace InjectedStatePackParams {
    const LABEL_EXECUTE = 8586780551181678328006076363877;
    const INCLUSION = 1944862448358072610670;
    const NON_INCLUSION = 8749584145069082368101870825326;
    const WRITE = 513020621925;

    func label(label: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = InjectedStatePackParams.LABEL_EXECUTE;
        assert params[1] = label;

        return (params=params, params_len=2);
    }

    func read_inclusion(root: felt, value: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = InjectedStatePackParams.INCLUSION;
        assert params[1] = root;
        assert params[2] = value;

        return (params=params, params_len=3);
    }

    func read_non_inclusion(root: felt, value: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = InjectedStatePackParams.NON_INCLUSION;
        assert params[1] = root;
        assert params[2] = value;

        return (params=params, params_len=3);
    }

    func write(root: felt, value: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = InjectedStatePackParams.WRITE;
        assert params[1] = root;
        assert params[2] = value;

        return (params=params, params_len=3);
    }
}

namespace InjectedStateHashParams {
    func label{poseidon_ptr: PoseidonBuiltin*}(label: felt) -> felt {
        let (params, params_len) = InjectedStatePackParams.label(
            label=label
        );
        return hash_memorizer_key(params, params_len);
    }

    func read_inclusion{poseidon_ptr: PoseidonBuiltin*}(root: felt, value: felt) -> felt {
        let (params, params_len) = InjectedStatePackParams.read_inclusion(
            root=root, value=value
        );
        return hash_memorizer_key(params, params_len);
    }

    func read_non_inclusion{poseidon_ptr: PoseidonBuiltin*}(root: felt, value: felt) -> felt {
        let (params, params_len) = InjectedStatePackParams.read_non_inclusion(
            root=root, value=value
        );
        return hash_memorizer_key(params, params_len);
    }

    func write{poseidon_ptr: PoseidonBuiltin*}(root: felt, value: felt) -> felt {
        let (params, params_len) = InjectedStatePackParams.write(
            root=root, value=value
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
