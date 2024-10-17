from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.default_dict import default_dict_new

namespace BareMemorizer {
    const DEFAULT_VALUE = 0x81;  // Invalid RLP value
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;

        let (local dict: DictAccess*) = default_dict_new(default_value=DEFAULT_VALUE);
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

namespace SingleBareMemorizer {
    const DEFAULT_VALUE = 0x0;  // Invalid RLP value
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;

        let (local dict: DictAccess*) = default_dict_new(default_value=DEFAULT_VALUE);
        tempvar dict_start = dict;

        return (dict_ptr=dict, dict_ptr_start=dict_start);
    }

    func add{dict_ptr: DictAccess*}(key: felt, item: felt) {
        dict_write(key=key, new_value=item);

        return ();
    }

    func get{dict_ptr: DictAccess*}(key: felt) -> (felt,) {
        let (item: felt) = dict_read(key=key);
        return (item=item);
    }
}
