from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.hdp.rlp import retrieve_from_rlp_list_via_idx, le_u64_array_to_uint256
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
)
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak

from src.hdp.types import Transaction, ChainInfo
from src.libs.rlp_little import extract_n_bytes_from_le_64_chunks_array
from src.hdp.utils import (
    prepend_le_rlp_list_prefix,
    append_be_chunk,
    get_chunk_bytes_len,
    reverse_chunk_endianess,
)
from starkware.cairo.common.cairo_secp.bigint import BigInt3, uint256_to_bigint

namespace TransactionField {
    const NONCE = 0;
    const GAS_PRICE = 1;
    const GAS_LIMIT = 2;
    const RECEIVER = 3;
    const VALUE = 4;
    const INPUT = 5;
    const V = 6;
    const R = 7;
    const S = 8;
    const CHAIN_ID = 9;
    const ACCESS_LIST = 10;
    const MAX_FEE_PER_GAS = 11;
    const MAX_PRIORITY_FEE_PER_GAS = 12;
    const BLOB_VERSIONED_HASHES = 13;
    const MAX_FEE_PER_BLOB_GAS = 14;
}

namespace TransactionType {
    const LEGACY = 0;
    const EIP2930 = 1;
    const EIP1559 = 2;
    const EIP4844 = 3;
}

namespace TransactionReader {
    func get_nonce{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction
    ) -> felt {
        let index = TxTypeFieldMap.get_field_index(tx.type, 0);
        let (nonce, nonce_len, _bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        assert nonce_len = 1;
        return (nonce[0]);
    }

    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction, field: felt
    ) -> Uint256 {
        if (field == TransactionField.RECEIVER) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.INPUT) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.ACCESS_LIST) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.BLOB_VERSIONED_HASHES) {
            assert 1 = 0;  // returns as felt
        }

        let index = TxTypeFieldMap.get_field_index(tx.type, field);
        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        return le_u64_array_to_uint256(res, res_len, bytes_len);
    }

    func get_field_and_bytes_len{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
    }(
        tx: Transaction, field: felt
    ) -> (value: Uint256, bytes_len: felt) {
        alloc_locals;
        if (field == TransactionField.RECEIVER) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.INPUT) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.ACCESS_LIST) {
            assert 1 = 0;  // returns as felt
        }

        if (field == TransactionField.BLOB_VERSIONED_HASHES) {
            assert 1 = 0;  // returns as felt
        }

        let index = TxTypeFieldMap.get_field_index(tx.type, field);
        let (local res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);
        let value = le_u64_array_to_uint256(res, res_len, bytes_len);
        return (value=value, bytes_len=bytes_len);
    }

    func get_felt_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction, field
    ) -> (value: felt*, value_len: felt, bytes_len: felt) {
        let index = TxTypeFieldMap.get_field_index(tx.type, field);

        let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx(tx.rlp, index, 0, 0);

        return (res, res_len, bytes_len);
    }
}

// Deriving the sender is an expensive operation, as it requires the recovery of the public key from the signature.
// For this reason, this logic is in its own namespace.
namespace TransactionSender {
    func derive{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        keccak_ptr: KeccakBuiltin*,
        chain_info: ChainInfo,
    }(tx: Transaction) -> felt {
        alloc_locals;

        let v_le = TransactionReader.get_field(tx, TransactionField.V);
        let (v) = uint256_reverse_endian(v_le);
        let (v_norm, is_eip155) = normalize_v{
            range_check_ptr=range_check_ptr, chain_info=chain_info
        }(tx.type, v);

        let (r_le, r_bytes_len) = TransactionReader.get_field_and_bytes_len(tx, TransactionField.R);
        let (r) = uint256_reverse_endian(r_le);
        let (s_le, s_bytes_len) = TransactionReader.get_field_and_bytes_len(tx, TransactionField.S);
        let (s) = uint256_reverse_endian(s_le);
       
        let (tx_payload, tx_payload_len, tx_payload_bytes_len) = extract_tx_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(tx, r_bytes_len + s_bytes_len + 3, is_eip155); // + 2 for s + r prefix, +1 for v

        let (
            encoded_tx_payload, encoded_tx_payload_len, encoded_tx_payload_bytes_len
        ) = rlp_encode_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(tx, tx_payload, tx_payload_len, tx_payload_bytes_len);

        let (big_r) = uint256_to_bigint(r);
        let (big_s) = uint256_to_bigint(s);

        // Now we hash this reencoded transaction, which is what the sender has signed in the first place
        let (msg_hash) = keccak_bigend(encoded_tx_payload, encoded_tx_payload_bytes_len);
        let (big_msg_hash) = uint256_to_bigint(msg_hash);
        let (pub) = recover_public_key(big_msg_hash, big_r, big_s, v_norm);

        local address: felt;
        let (keccak_ptr_seg: felt*) = alloc();
        local keccak_ptr_seg_start: felt* = keccak_ptr_seg;

        with keccak_ptr_seg {
            let (local public_address) = public_key_point_to_eth_address{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr_seg
            }(pub);

            assert address = public_address;
            finalize_keccak(keccak_ptr_start=keccak_ptr_seg_start, keccak_ptr_end=keccak_ptr_seg);
        }

        return (address);
    }

    func extract_tx_payload{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, chain_info: ChainInfo
    }(tx: Transaction, sig_bytes_len: felt, is_eip155: felt) -> (tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt) {
        alloc_locals;

        let tx_params_bytes_len = tx.bytes_len - sig_bytes_len;

        // since the TX doesnt contain the list prefix, we simply retrieve the bytes, ignoring the signature ones
        let (tx_params, tx_params_len) = extract_n_bytes_from_le_64_chunks_array(
            array=tx.rlp,
            start_word=0,
            start_offset=0,
            n_bytes=tx_params_bytes_len,
            pow2_array=pow2_array,
        );

        // deal with EIP155
        if (is_eip155 == 1) {
            let eip155_append = chain_info.id * pow2_array[16] + 0x8080;
            let eip155_bytes_len = chain_info.id_bytes_len + 2;

            let (tx_payload, tx_payload_len, tx_payload_bytes_len) = append_be_chunk{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
            }(tx_params, tx_params_bytes_len, eip155_append, eip155_bytes_len);

            return (tx_payload, tx_payload_len, tx_payload_bytes_len);
        } else {
            return (tx_params, tx_params_len, tx_params_bytes_len);
        }
    }

    // Encode encoded tx payload
    // This function accepts the RLP encoded parameters of a transaction and encodes them in to their signing form. This is the form that the sender has signed.
    // Inputs:
    //     tx: Transaction - The transaction object
    //     tx_payload: felt* - The RLP encoded transaction parameters. This does not include the RLP list prefix.
    //     tx_payload_len: felt - The number of 64bit chunks in the tx_payload
    //     tx_payload_bytes_len: felt - The number of bytes in the tx_payload
    // Outputs:
    //     signed_payload: felt* - The encoded transaction payload in the form that the sender has signed
    //     signed_payload_len: felt - The number of 64bit chunks in the signed_payload
    //     signed_payload_bytes_len: felt - The number of bytes in the signed_payload
    func rlp_encode_payload{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction, tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt
    ) -> (signed_payload: felt*, signed_payload_len: felt, signed_payload_bytes_len: felt) {
        alloc_locals;
        local prefix: felt;
        local prefix_bytes_len: felt;

        local is_short: felt;
        %{ ids.is_short = 1 if ids.tx_payload_bytes_len <= 55 else 0 %}
        local prefix: felt;
        local current_len: felt;
        if (is_short == 1) {
            // Calculate the prefix for an RLP short list
            assert [range_check_ptr] = 55 - tx_payload_bytes_len;
            assert prefix = 0xc0 + tx_payload_bytes_len;
            assert current_len = 1;
            tempvar range_check_ptr = range_check_ptr + 1;
        } else {
            // Calculate the prefix for an RLP long list
            let len_len = get_chunk_bytes_len(tx_payload_bytes_len);
            assert [range_check_ptr] = tx_payload_bytes_len - 56;
            assert prefix = (0xf7 + len_len) * pow2_array[8 * len_len] + tx_payload_bytes_len;
            assert current_len = len_len + 1;
            tempvar range_check_ptr = range_check_ptr + 1;
        }

        local typed_prefix: felt;
        if(tx.type == TransactionType.LEGACY) {
             // Legacy txs have no type prefix

            assert prefix_bytes_len = current_len;
            let le_prefix = reverse_chunk_endianess(prefix, prefix_bytes_len);
            assert typed_prefix = le_prefix;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            // All txs past EIP155 have a type prefix
            assert [range_check_ptr] = tx.type - 1;
            tempvar range_check_ptr = range_check_ptr + 1;
            assert prefix_bytes_len = current_len + 1;

            // prepend the tx type to the prefix and convert to LE
            let be_typed_prefix = tx.type * pow2_array[8 * current_len] + prefix;
            let le_typed_prefix = reverse_chunk_endianess(be_typed_prefix, prefix_bytes_len);

            assert typed_prefix = le_typed_prefix;
            tempvar range_check_ptr = range_check_ptr;
        }

        // We have generated the RLP prefix in a hint, now we need to shift all values to fit the LE 64bit array format
        let (encoded_tx, encoded_tx_len) = prepend_le_rlp_list_prefix(
            offset=prefix_bytes_len, prefix=typed_prefix, rlp=tx_payload, rlp_len=tx_payload_len
        );
        let encoded_tx_bytes_len = tx_payload_bytes_len + prefix_bytes_len;

        return (encoded_tx, encoded_tx_len, encoded_tx_bytes_len);
    }

    // The extract the public key of the sende, we need to normalize the signatures v parameter.
    // For legacy transactions, we also need to check if it is an EIP155 transaction. This can be derived by the V parameter.
    func normalize_v{
        range_check_ptr,
        chain_info: ChainInfo,
    }(tx_type: felt, v: Uint256) -> (v_norm: felt, is_eip155: felt) {
        alloc_locals;

        local is_eip155: felt;
        local v_norm: felt;
        %{ ids.is_eip155 = 1 if ids.chain_info.id * 2 + 35 <= ids.v.low <= ids.chain_info.id * 2 + 36 else 0 %}
        // a tx uses EIP155 if the V value is in the range of [chain_id * 2 + 35, chain_id * 2 + 36]
        if(is_eip155 == 1) {
            assert [range_check_ptr] = (chain_info.id * 2 + 36) - v.low;
            assert [range_check_ptr + 1] = v.low - (chain_info.id * 2 + 35);
            assert tx_type = TransactionType.LEGACY;
            assert v_norm = v.low - (chain_info.id * 2 + 35);

            tempvar range_check_ptr = range_check_ptr + 2;
        } else {
            // if its not eip155, V must be smaller
            assert [range_check_ptr] = (chain_info.id * 2 + 35) - v.low;
            if (tx_type == TransactionType.LEGACY) {
                assert [range_check_ptr + 1] = v.low - 27; // In theory, this should never fail
                assert v_norm = v.low - 27;
                tempvar range_check_ptr = range_check_ptr + 2;
            } else {
                assert [range_check_ptr + 1] = v.low - 1; // In theory, this should never fail
                assert [range_check_ptr + 2] = tx_type - 1;
                assert v_norm = v.low;
                tempvar range_check_ptr = range_check_ptr + 3;
            }
        }
        return (v_norm, is_eip155);
    }
}

// The layout of the different transaction types depends on the type of transaction. Some fields are only available in certain types of transactions.
// For this reason we must map all available fields to the corresponding index in the transaction object.
namespace TxTypeFieldMap {
    func get_field_index(tx_type: felt, field: felt) -> felt {
        if (tx_type == TransactionType.LEGACY) {
            return get_legacy_tx_field_index(field);
        }

        if (tx_type == TransactionType.EIP2930) {
            return get_eip2930_tx_field_index(field);
        }

        if (tx_type == TransactionType.EIP1559) {
            return get_eip1559_tx_field_index(field);
        }

        if (tx_type == TransactionType.EIP4844) {
            return get_eip4844_tx_field_index(field);
        }

        assert 1 = 0;
        return 0;
    }

    // Legacy/EIP155:
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
    func get_legacy_tx_field_index(field: felt) -> felt {
        if (field == TransactionField.NONCE) {
            return 0;
        }
        if (field == TransactionField.GAS_PRICE) {
            return 1;
        }
        if (field == TransactionField.GAS_LIMIT) {
            return 2;
        }
        if (field == TransactionField.RECEIVER) {
            return 3;
        }
        if (field == TransactionField.VALUE) {
            return 4;
        }
        if (field == TransactionField.INPUT) {
            return 5;
        }
        if (field == TransactionField.V) {
            return 6;
        }
        if (field == TransactionField.R) {
            return 7;
        }
        if (field == TransactionField.S) {
            return 8;
        }

        assert 1 = 0;
        return 0;
    }

    // Eip2930:
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

    func get_eip2930_tx_field_index(field: felt) -> felt {
        if (field == TransactionField.NONCE) {
            return 1;
        }
        if (field == TransactionField.GAS_PRICE) {
            return 2;
        }
        if (field == TransactionField.GAS_LIMIT) {
            return 3;
        }
        if (field == TransactionField.RECEIVER) {
            return 4;
        }
        if (field == TransactionField.VALUE) {
            return 5;
        }
        if (field == TransactionField.INPUT) {
            return 6;
        }
        if (field == TransactionField.V) {
            return 8;
        }
        if (field == TransactionField.R) {
            return 9;
        }
        if (field == TransactionField.S) {
            return 10;
        }
        if (field == TransactionField.CHAIN_ID) {
            return 0;
        }
        if (field == TransactionField.ACCESS_LIST) {
            return 7;
        }

        assert 1 = 0;
        return 0;
    }

    // Eip1559:
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
    func get_eip1559_tx_field_index(field: felt) -> felt {
        if (field == TransactionField.NONCE) {
            return 1;
        }
        if (field == TransactionField.GAS_PRICE) {
            assert 1 = 0;  // not available in eip1559
        }
        if (field == TransactionField.GAS_LIMIT) {
            return 4;
        }
        if (field == TransactionField.RECEIVER) {
            return 5;
        }
        if (field == TransactionField.VALUE) {
            return 6;
        }
        if (field == TransactionField.INPUT) {
            return 7;
        }
        if (field == TransactionField.V) {
            return 9;
        }
        if (field == TransactionField.R) {
            return 10;
        }
        if (field == TransactionField.S) {
            return 11;
        }
        if (field == TransactionField.CHAIN_ID) {
            return 0;
        }
        if (field == TransactionField.ACCESS_LIST) {
            return 8;
        }
        if (field == TransactionField.MAX_FEE_PER_GAS) {
            return 3;
        }
        if (field == TransactionField.MAX_PRIORITY_FEE_PER_GAS) {
            return 2;
        }

        assert 1 = 0;
        return 0;
    }

    // Eip4844:
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
    func get_eip4844_tx_field_index(field: felt) -> felt {
        if (field == TransactionField.NONCE) {
            return 1;
        }
        if (field == TransactionField.GAS_PRICE) {
            assert 1 = 0;
        }
        if (field == TransactionField.GAS_LIMIT) {
            return 4;
        }
        if (field == TransactionField.RECEIVER) {
            return 5;
        }
        if (field == TransactionField.VALUE) {
            return 6;
        }
        if (field == TransactionField.INPUT) {
            return 7;
        }
        if (field == TransactionField.V) {
            return 11;
        }
        if (field == TransactionField.R) {
            return 12;
        }
        if (field == TransactionField.S) {
            return 13;
        }
        if (field == TransactionField.CHAIN_ID) {
            return 0;
        }
        if (field == TransactionField.ACCESS_LIST) {
            return 8;
        }
        if (field == TransactionField.MAX_FEE_PER_GAS) {
            return 3;
        }
        if (field == TransactionField.MAX_PRIORITY_FEE_PER_GAS) {
            return 2;
        }
        if (field == TransactionField.MAX_FEE_PER_BLOB_GAS) {
            return 9;
        }
        if (field == TransactionField.BLOB_VERSIONED_HASHES) {
            return 10;
        }

        assert 1 = 0;
        return 0;
    }
}
