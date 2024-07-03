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

    func account(chain_id: felt, block_number: felt, address: felt) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;

        return (params=params, params_len=3);
    }

    func storage(chain_id: felt, block_number: felt, address: felt, storage_slot: felt*) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;
        memcpy(dst=params + 3, src=storage_slot, len=4);

        return (params=params, params_len=7);
    }

    func block_tx(chain_id: felt, block_number: felt, key_low: felt) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = key_low;

        return (params=params, params_len=3);
    }

    func block_receipt{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = key_low;

        return (params=params, params_len=3);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
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
        chain_id: felt, block_number: felt, address: felt, rlp: felt*
    ) {
        let (params, params_len) = PackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=account_dict}(key, rlp);

        return ();
    }

    func get{account_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt
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
        chain_id: felt, block_number: felt, address: felt, storage_slot: felt*, rlp: felt*
    ) {
        let (params, params_len) = PackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=storage_dict}(key, rlp);

        return ();
    }

    func get{storage_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt, storage_slot: felt*
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=storage_dict}(key);
        return (rlp=rlp);
    }
}

namespace BlockTxMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{block_tx_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt, rlp: felt*
    ) {
        let (params, params_len) = PackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=block_tx_dict}(key, rlp);

        return ();
    }

    func get{block_tx_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=block_tx_dict}(key);
        return (rlp=rlp);
    }
}

namespace BlockReceiptMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{block_receipt_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt, rlp: felt*
    ) {
        let (params, params_len) = PackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=block_receipt_dict}(key, rlp);

        return ();
    }

    func get{block_receipt_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = PackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=block_receipt_dict}(key);
        return (rlp=rlp);
    }
}