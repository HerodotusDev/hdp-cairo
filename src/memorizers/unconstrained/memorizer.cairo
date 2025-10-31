from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from src.memorizers.bare import BareMemorizer

namespace UnconstrainedPackParams {
    func bytecode(chain_id: felt, block_number: felt, address: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;

        return (params=params, params_len=3);
    }
}

namespace UnconstrainedHashParams {
    func bytecode{poseidon_ptr: PoseidonBuiltin*}(chain_id: felt, block_number: felt, address: felt) -> felt {
        let (params, params_len) = UnconstrainedPackParams.bytecode(
            chain_id=chain_id, block_number=block_number, address=address
        );
        return hash_memorizer_key(params, params_len);
    }
}

namespace UnconstrainedHashParams2 {
    func bytecode{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        let (params, params_len) = UnconstrainedPackParams.bytecode(params[0], params[1], params[2]);
        return hash_memorizer_key(params, params_len);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

//! TODO: @Okm165 - this needs fixing, definitely rlp shouldn't be here...
namespace UnconstrainedMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{unconstrained_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt, data: felt*) {
        BareMemorizer.add{dict_ptr=unconstrained_memorizer}(key, data);

        return ();
    }

    func get{unconstrained_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt) -> (
        rlp: felt*
    ) {
        let (rlp) = BareMemorizer.get{dict_ptr=unconstrained_memorizer}(key);
        return (rlp=rlp);
    }
}
