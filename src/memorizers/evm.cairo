from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.dict import dict_new
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc

from src.memorizers.bare import BareMemorizer

namespace EvmPackParams {
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

    func storage(chain_id: felt, block_number: felt, address: felt, storage_slot: Uint256) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;
        assert params[3] = storage_slot.high;
        assert params[4] = storage_slot.low;

        return (params=params, params_len=5);
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

namespace EvmHeaderMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, rlp: felt*
    ) {
        let (params, params_len) = EvmPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=header_dict}(key, rlp);

        return ();
    }

    func get{header_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = EvmPackParams.header(
            chain_id=chain_id, block_number=block_number
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=header_dict}(key);
        return (rlp=rlp);
    }
}

namespace EvmAccountMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{account_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt, rlp: felt*
    ) {
        let (params, params_len) = EvmPackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=account_dict}(key, rlp);

        return ();
    }

    func get{account_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = EvmPackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=account_dict}(key);
        return (rlp=rlp);
    }
}

namespace EvmStorageMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{storage_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt, storage_slot: Uint256, rlp: felt*
    ) {
        let (params, params_len) = EvmPackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=storage_dict}(key, rlp);

        return ();
    }

    func get{storage_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt, storage_slot: Uint256
    ) -> (rlp: felt*) {
        let (params, params_len) = EvmPackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=storage_dict}(key);
        return (rlp=rlp);
    }
}

namespace EvmBlockTxMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{block_tx_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt, rlp: felt*
    ) {
        let (params, params_len) = EvmPackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=block_tx_dict}(key, rlp);

        return ();
    }

    func get{block_tx_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = EvmPackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=block_tx_dict}(key);
        return (rlp=rlp);
    }
}

namespace EvmBlockReceiptMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{block_receipt_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt, rlp: felt*
    ) {
        let (params, params_len) = EvmPackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        BareMemorizer.add{dict_ptr=block_receipt_dict}(key, rlp);

        return ();
    }

    func get{block_receipt_dict: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (rlp: felt*) {
        let (params, params_len) = EvmPackParams.block_tx(
            chain_id=chain_id, block_number=block_number, key_low=key_low
        );

        let key = hash_memorizer_key(params, params_len);
        let (rlp) = BareMemorizer.get{dict_ptr=block_receipt_dict}(key);
        return (rlp=rlp);
    }
}