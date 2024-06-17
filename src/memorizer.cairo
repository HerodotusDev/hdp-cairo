from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import (
    poseidon_hash_single,
    poseidon_hash,
    poseidon_hash_many,
)
from starkware.cairo.common.dict import dict_write, dict_read
from src.types import Header, AccountValues, Transaction, Receipt
from starkware.cairo.common.uint256 import Uint256

const MEMORIZER_DEFAULT = 100000000;  // An arbitrary large number. We need to ensure each memorizer never contains >= number of elements.

// Memorizer is very incomplete. It is just a sketch of how it could look like.

namespace HeaderMemorizer {
    func initialize{}() -> (header_dict: DictAccess*, header_dict_start: DictAccess*) {
        let (header_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar header_dict_start = header_dict;

        return (header_dict=header_dict, header_dict_start=header_dict_start);
    }

    func add{header_dict: DictAccess*}(chain_id: felt, block_number: felt, index: felt) {
        dict_write{dict_ptr=header_dict}(
            key=gen_header_key(chain_id, block_number), new_value=index
        );
        return ();
    }

    func get{header_dict: DictAccess*, headers: Header*}(
        chain_id: felt, block_number: felt
    ) -> Header {
        alloc_locals;
        let (index) = dict_read{dict_ptr=header_dict}(key=gen_header_key(chain_id, block_number));

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (headers[index]);
    }
}

func gen_header_key{poseidon_ptr: PoseidonBuiltin*}(chain_id: felt, block_number: felt) -> felt {
    alloc_locals;

    local data: felt* = nondet %{ segment.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;

    let (res) = poseidon_hash_many(2, data);
    return res;
}

namespace AccountMemorizer {
    func initialize{}() -> (account_dict: DictAccess*, account_dict_start: DictAccess*) {
        let (account_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar account_dict_start = account_dict;

        return (account_dict=account_dict, account_dict_start=account_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, account_dict: DictAccess*}(
        chain_id: felt, block_number: felt, address: felt*, index: felt
    ) {
        dict_write{dict_ptr=account_dict}(
            key=gen_account_key(chain_id, block_number, address), new_value=index
        );
        return ();
    }

    func get{
        account_dict: DictAccess*, account_values: AccountValues*, poseidon_ptr: PoseidonBuiltin*
    }(chain_id: felt, block_number: felt, address: felt*) -> (account_value: AccountValues) {
        alloc_locals;
        let (index) = dict_read{dict_ptr=account_dict}(
            gen_account_key(chain_id, block_number, address)
        );

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (account_value=account_values[index]);
    }
}

func gen_account_key{poseidon_ptr: PoseidonBuiltin*}(
    chain_id: felt, block_number: felt, address: felt*
) -> felt {
    alloc_locals;

    local data: felt* = nondet %{ segment.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;
    assert data[2] = address[0];
    assert data[3] = address[1];
    assert data[4] = address[2];

    let (res) = poseidon_hash_many(5, data);
    return res;
}

namespace StorageMemorizer {
    func initialize{}() -> (storage_dict: DictAccess*, storage_dict_start: DictAccess*) {
        let (storage_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar storage_dict_start = storage_dict;

        return (storage_dict=storage_dict, storage_dict_start=storage_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, storage_dict: DictAccess*}(
        chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*, index: felt
    ) {
        dict_write{dict_ptr=storage_dict}(
            key=gen_storage_key(chain_id, block_number, address, storage_slot), new_value=index
        );
        return ();
    }

    func get{storage_dict: DictAccess*, storage_values: Uint256*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*
    ) -> (storage_value: Uint256) {
        alloc_locals;
        let (index) = dict_read{dict_ptr=storage_dict}(
            gen_storage_key(chain_id, block_number, address, storage_slot)
        );

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (storage_value=storage_values[index]);
    }
}

func gen_storage_key{poseidon_ptr: PoseidonBuiltin*}(
    chain_id: felt, block_number: felt, address: felt*, storage_slot: felt*
) -> felt {
    alloc_locals;

    local data: felt* = nondet %{ segment.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;
    assert data[2] = address[0];
    assert data[3] = address[1];
    assert data[4] = address[2];
    assert data[5] = storage_slot[0];
    assert data[6] = storage_slot[1];
    assert data[7] = storage_slot[2];
    assert data[8] = storage_slot[3];

    let (res) = poseidon_hash_many(9, data);
    return res;
}

namespace TransactionMemorizer {
    func initialize{}() -> (transaction_dict: DictAccess*, transaction_dict_start: DictAccess*) {
        let (transaction_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar transaction_dict_start = transaction_dict;

        return (transaction_dict=transaction_dict, transaction_dict_start=transaction_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, transaction_dict: DictAccess*}(
        chain_id: felt, block_number: felt, key_low: felt, index: felt
    ) {
        dict_write{dict_ptr=transaction_dict}(
            key=gen_transaction_key(chain_id, block_number, key_low), new_value=index
        );
        return ();
    }

    func get{
        transaction_dict: DictAccess*, transactions: Transaction*, poseidon_ptr: PoseidonBuiltin*
    }(chain_id: felt, block_number: felt, key_low: felt) -> (transaction: Transaction) {
        alloc_locals;
        let (index) = dict_read{dict_ptr=transaction_dict}(
            gen_transaction_key(chain_id, block_number, key_low)
        );

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (transaction=transactions[index]);
    }
}

func gen_transaction_key{poseidon_ptr: PoseidonBuiltin*}(
    chain_id: felt, block_number: felt, key_low: felt
) -> felt {
    alloc_locals;

    local data: felt* = nondet %{ segment.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;
    assert data[2] = key_low;

    let (res) = poseidon_hash_many(3, data);
    return res;
}

namespace ReceiptMemorizer {
    func initialize{}() -> (receipt_dict: DictAccess*, receipt_dict_start: DictAccess*) {
        let (receipt_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar receipt_dict_start = receipt_dict;

        return (receipt_dict=receipt_dict, receipt_dict_start=receipt_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, receipt_dict: DictAccess*}(
        chain_id: felt, block_number: felt, key_low: felt, index: felt
    ) {
        dict_write{dict_ptr=receipt_dict}(
            key=gen_receipt_key(chain_id, block_number, key_low), new_value=index
        );
        return ();
    }

    func get{receipt_dict: DictAccess*, receipts: Receipt*, poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (receipt: Receipt) {
        alloc_locals;
        let (index) = dict_read{dict_ptr=receipt_dict}(
            gen_receipt_key(chain_id, block_number, key_low)
        );

        if (index == MEMORIZER_DEFAULT) {
            assert 1 = 0;
        }

        return (receipt=receipts[index]);
    }
}

func gen_receipt_key{poseidon_ptr: PoseidonBuiltin*}(
    chain_id: felt, block_number: felt, key_low: felt
) -> felt {
    alloc_locals;

    local data: felt* = nondet %{ segment.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;
    assert data[2] = key_low;

    let (res) = poseidon_hash_many(3, data);
    return res;
}
