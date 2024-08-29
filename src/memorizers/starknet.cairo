from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from src.memorizers.bare import BareMemorizer

namespace StarknetPackParams {
    func header(chain_id: felt, block_number: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;

        return (params=params, params_len=2);
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

    func add{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, rlp: felt*
    ) {
        let (params, params_len) = StarknetPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=header_dict}(key, rlp);

        return ();
    }

    func get{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = StarknetPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=header_dict}(key);
        return (rlp=rlp);
    }
}