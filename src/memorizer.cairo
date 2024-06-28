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
from starkware.cairo.common.memcpy import memcpy

const MEMORIZER_DEFAULT = 100000000;  // An arbitrary large number. We need to ensure each memorizer never contains >= number of elements.

// Memorizer is very incomplete. It is just a sketch of how it could look like.

namespace TransactionMemorizer {
    func initialize{}() -> (transaction_dict: DictAccess*, transaction_dict_start: DictAccess*) {
        let (transaction_dict) = default_dict_new(default_value=MEMORIZER_DEFAULT);
        tempvar transaction_dict_start = transaction_dict;

        return (transaction_dict=transaction_dict, transaction_dict_start=transaction_dict_start);
    }

    func add{poseidon_ptr: PoseidonBuiltin*, transaction_dict: DictAccess*}(
        chain_id: felt, block_number: felt, key_low: felt, index: felt
    ) {
        let key = gen_transaction_key(chain_id, block_number, key_low);
        dict_write{dict_ptr=transaction_dict}(key=key, new_value=index);
        return ();
    }

    func get{
        poseidon_ptr: PoseidonBuiltin*, transaction_dict: DictAccess*, transactions: Transaction*
    }(chain_id: felt, block_number: felt, key_low: felt) -> (transaction: Transaction) {
        alloc_locals;
        let key = gen_transaction_key(chain_id, block_number, key_low);
        let (index) = dict_read{dict_ptr=transaction_dict}(key=key);

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

    local data: felt* = nondet %{ segments.add() %};
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
        let key = gen_receipt_key(chain_id, block_number, key_low);
        dict_write{dict_ptr=receipt_dict}(key=key, new_value=index);
        return ();
    }

    func get{poseidon_ptr: PoseidonBuiltin*, receipt_dict: DictAccess*, receipts: Receipt*}(
        chain_id: felt, block_number: felt, key_low: felt
    ) -> (receipt: Receipt) {
        alloc_locals;
        let key = gen_receipt_key(chain_id, block_number, key_low);
        let (index) = dict_read{dict_ptr=receipt_dict}(key=key);

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

    local data: felt* = nondet %{ segments.add() %};
    assert data[0] = chain_id;
    assert data[1] = block_number;
    assert data[2] = key_low;

    let (res) = poseidon_hash_many(3, data);
    return res;
}
