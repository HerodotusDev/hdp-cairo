from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import (
    poseidon_hash_single,
    poseidon_hash,
    poseidon_hash_many,
)
from starkware.cairo.common.dict import dict_write, dict_read
from src.hdp.types import Header, AccountValues, Transaction
from starkware.cairo.common.uint256 import Uint256

const MEMORIZER_DEFAULT = 100000000;  // An arbitrary large number. We need to ensure each memorizer never contains >= number of elements.

// Memorizer is very incomplete. It is just a sketch of how it could look like.

namespace HeaderMemorizer {
    func initialize{}() -> (header_dict: DictAccess*, header_dict_start: DictAccess*) {
        let (header_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar header_dict_start = header_dict;

        return (header_dict=header_dict, header_dict_start=header_dict_start);
    }

    func add{header_dict: DictAccess*}(block_number: felt, index: felt) {
        dict_write{dict_ptr=header_dict}(key=block_number, new_value=index);
        return ();
    }

    func get{header_dict: DictAccess*, headers: Header*}(block_number: felt) -> Header {
        alloc_locals;
        let (index) = dict_read{dict_ptr=header_dict}(block_number);

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (headers[index]);
    }
}

namespace AccountMemorizer {
    func initialize{}() -> (account_dict: DictAccess*, account_dict_start: DictAccess*) {
        let (account_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar account_dict_start = account_dict;

        return (account_dict=account_dict, account_dict_start=account_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, account_dict: DictAccess*}(
        address: felt*, block_number: felt, index: felt
    ) {
        let key = gen_account_key(address, block_number);
        dict_write{dict_ptr=account_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        account_dict: DictAccess*, account_values: AccountValues*, poseidon_ptr: PoseidonBuiltin*
    }(address: felt*, block_number: felt) -> (account_value: AccountValues) {
        alloc_locals;
        let key = gen_account_key(address, block_number);
        let (index) = dict_read{dict_ptr=account_dict}(key);

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (account_value=account_values[index]);
    }
}

namespace StorageMemorizer {
    func initialize{}() -> (storage_dict: DictAccess*, storage_dict_start: DictAccess*) {
        let (storage_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar storage_dict_start = storage_dict;

        return (storage_dict=storage_dict, storage_dict_start=storage_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, storage_dict: DictAccess*}(
        storage_slot: felt*, address: felt*, block_number: felt, index: felt
    ) {
        let key = gen_storage_key(storage_slot, address, block_number);

        dict_write{dict_ptr=storage_dict}(key=key, new_value=index);
        return ();
    }

    func get{storage_dict: DictAccess*, storage_values: Uint256*, poseidon_ptr: PoseidonBuiltin*}(
        storage_slot: felt*, address: felt*, block_number: felt
    ) -> (storage_value: Uint256) {
        alloc_locals;
        let key = gen_storage_key(storage_slot, address, block_number);
        let (index) = dict_read{dict_ptr=storage_dict}(key);

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (storage_value=storage_values[index]);
    }
}

namespace TransactionMemorizer {
    func initialize{}() -> (transaction_dict: DictAccess*, transaction_dict_start: DictAccess*) {
        let (transaction_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar transaction_dict_start = transaction_dict;

        return (transaction_dict=transaction_dict, transaction_dict_start=transaction_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, transaction_dict: DictAccess*}(
        sender: felt*, nonce: felt, index: felt
    ) {
        let key = gen_transaction_key(sender, nonce);

        dict_write{dict_ptr=transaction_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        transaction_dict: DictAccess*, transactions: Transaction*, poseidon_ptr: PoseidonBuiltin*
    }(sender: felt*, nonce: felt) -> (transaction: Transaction) {
        alloc_locals;
        let key = gen_transaction_key(sender, nonce);
        let (index) = dict_read{dict_ptr=transaction_dict}(key);

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (transaction=transactions[index]);
    }
}

// the account key is h(slot.key, account_key).
// ToDo: too much hashing
func gen_storage_key{poseidon_ptr: PoseidonBuiltin*}(
    storage_slot: felt*, address: felt*, block_number: felt
) -> felt {
    alloc_locals;

    let account_key = gen_account_key(address, block_number);
    let (h_key) = poseidon_hash_many(4, storage_slot);
    let (res) = poseidon_hash(h_key, account_key);

    return res;
}

// the account key is h(h(address), block_number).
// ToDo: too much hashing
func gen_account_key{poseidon_ptr: PoseidonBuiltin*}(address: felt*, block_number: felt) -> felt {
    let (h_addr) = poseidon_hash_many(3, address);
    let (res) = poseidon_hash(h_addr, block_number);

    return res;
}

func gen_transaction_key{poseidon_ptr: PoseidonBuiltin*}(sender: felt*, nonce: felt) -> felt {
    let (h_sender) = poseidon_hash_many(3, sender);
    let (res) = poseidon_hash(h_sender, nonce);

    return res;
}