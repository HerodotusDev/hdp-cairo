from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.hdp.rlp import retrieve_from_rlp_list_via_idx, le_u64_array_to_uint256
from src.hdp.types import Transaction


// Available Fields:
//     0: Nonce
//     1: Gas Price
//     2: Gas Limit
//     3: To
//     4: Value
//     5: Inputs
//     6: V
//     7: R
//     8: S
//     9: Chain Id
//     10: Access List
//     11: Max Fee Per Gas
//     12: Max Priority Fee Per Gas
//     13: Max Fee Per Blob Gas
//     14: Blob Versioned Hashes
namespace TransactionReader {
    func get_nonce{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    } (tx: Transaction) -> felt {
        let index = TxTypeFieldMap.get_field_index(tx.type, 0);
        let (nonce, nonce_len, _bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        assert nonce_len = 1;
        return (nonce[0]);
    }

    func get_field_by_index{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(tx: Transaction, field: felt) -> Uint256 {
        if(field == 3) {
            assert 1 = 0; // returns as felt
        }

        if(field == 5) {
            assert 1 = 0; // returns as felt
        }

        if(field == 10) {
            assert 1 = 0; // returns as felt
        }

        if(field == 14) {
            assert 1 = 0; // returns as felt
        }

        let index = TxTypeFieldMap.get_field_index(tx.type, field);
        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        return le_u64_array_to_uint256(res, res_len, bytes_len, 1);
    }

    func get_felt_field_by_index{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*
    }(tx: Transaction, field) -> (value: felt*, value_len: felt, bytes_len: felt) {
        let index = TxTypeFieldMap.get_field_index(tx.type, field);
        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        return (res, res_len, bytes_len);
    }
}



// The layout of the different transaction types depends on the type of transaction. Some fields are only available in certain types of transactions.
// For this reason we must map all available fields to the corresponding index in the transaction object.
namespace TxTypeFieldMap {
    func get_field_index(tx_type: felt, field: felt) -> felt {
        if(tx_type == 0) {
            return get_tx_type_0_field_index(field);
        }

        if(tx_type == 1) {
            return get_tx_type_1_field_index(field);
        }

        if(tx_type == 2) {
            return get_tx_type_2_field_index(field);
        }

        if(tx_type == 3) {
            return get_tx_type_3_field_index(field);
        }

        assert 1 = 0;
        return 0;
    }

// Type 0:
//     0: Nonce
//     1: Gas Price
//     2: Gas Limit
//     3: To
//     4: Value
//     5: Inputs
//     6: V
//     7: R
//     8: S
// ToDo: Consider implementing with dw. Not how how to handle the assert statements though
    func get_tx_type_0_field_index(field: felt) -> felt {
        if(field == 0) {
            return 0;
        }
        if(field == 1) {
            return 1;
        }
        if(field == 2) {
            return 2;
        }
        if(field == 3) {
            return 3;
        }
        if(field == 4) {
            return 4;
        }
        if(field == 5) {
            return 5;
        }
        if(field == 6) {
            return 6;
        }
        if(field == 7) {
            return 7;
        }
        if(field == 8) {
            return 8;
        }
        if(field == 9) {
            assert 1 = 0;
        }
        if(field == 10) {
            assert 1 = 0;
        }
        if(field == 11) {
            assert 1 = 0;
        }
        if(field == 12) {
            assert 1 = 0;
        }
        if(field == 13) {
            assert 1 = 0;
        }
        if(field == 14) {
            assert 1 = 0;
        }

        assert 1 = 0;
        return 0;
    }

// Type 1:
//     0: Chain Id
//     1: Nonce
//     2: Gas Price
//     3: Gas Limit
//     4: To
//     5: Value
//     6: Inputs
//     7: Access List
//     8: V
//     9: R
//     10: S

    func get_tx_type_1_field_index(field: felt) -> felt {
        if(field == 0) {
            return 1;
        }
        if(field == 1) {
            return 2;
        }
        if(field == 2) {
            return 3;
        }
        if(field == 3) {
            return 4;
        }
        if(field == 4) {
            return 5;
        }
        if(field == 5) {
            return 6;
        }
        if(field == 6) {
            return 8;
        }
        if(field == 7) {
            return 9;
        }
        if(field == 8) {
            return 10;
        }
        if(field == 9) {
            return 0;
        }
        if(field == 10) {
            return 7;
        }
        if(field == 11) {
            assert 1 = 0;
        }
        if(field == 12) {
            assert 1 = 0;
        }
        if(field == 13) {
            assert 1 = 0;
        }
        if(field == 14) {
            assert 1 = 0;
        }

        assert 1 = 0;
        return 0;
    }

// Type 2:
//     0: Chain Id
//     1: Nonce
//     2: Max Priority Fee Per Gas
//     3: Max Fee Per Gas
//     4: Gas Limit
//     5: To
//     6: Value
//     7: Inputs
//     8: Access List
//     9: V
//     10: R
//     11: S
    func get_tx_type_2_field_index(field: felt) -> felt {
        if(field == 0) {
            return 1;
        }
        if(field == 1) {
           assert 1 = 0; // not available in eip1559
        }
        if(field == 2) {
            return 4;
        }
        if (field == 3) {
            return 5;
        }
        if(field == 4) {
            return 6;
        }
        if(field == 5) {
            return 7;
        }
        if(field == 6) {
            return 9;
        }
        if(field == 7) {
            return 10;
        }
        if(field == 8) {
            return 11;
        }
        if(field == 9) {
            return 0;
        }
        if(field == 10) {
            return 8;
        }
        if(field == 11) {
            return 3;
        }
        if(field == 12) {
            return 2;
        }
        if(field == 13) {
            assert 1 = 0;
        }
        if(field == 14) {
            assert 1 = 0;
        }

        assert 1 = 0;
        return 0;
    }

// Type 3:
//     0: Chain Id
//     1: Nonce
//     2: Max Priority Fee Per Gas
//     3: Max Fee Per Gas
//     4: Gas Limit
//     5: To
//     6: Value
//     7: Inputs
//     8: Access List
//     9: Max Fee Per Blob Gas
//     10: Blob Versioned Hashes
//     11: V
//     12: R
//     13: S      
    func get_tx_type_3_field_index(field: felt) -> felt {
        if(field == 0) {
            return 1;
        }
        if(field == 1) {
           assert 1 = 0; // not available in eip1559
        }
        if(field == 2) {
            return 4;
        }
        if (field == 3) {
            return 5;
        }
        if(field == 4) {
            return 6;
        }
        if(field == 5) {
            return 7;
        }
        if(field == 6) {
            return 11;
        }
        if(field == 7) {
            return 12;
        }
        if(field == 8) {
            return 13;
        }
        if(field == 9) {
            return 0;
        }
        if(field == 10) {
            return 8;
        }
        if(field == 11) {
            return 3;
        }
        if(field == 12) {
            return 2;
        }
        if(field == 13) {
            return 9;
        }
        if(field == 14) {
            return 10;
        }

        assert 1 = 0;
        return 0;    
    }
}


