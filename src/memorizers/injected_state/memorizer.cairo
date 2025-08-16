from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from src.memorizers.bare import BareMemorizer

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
