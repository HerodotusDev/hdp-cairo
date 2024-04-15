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

from src.hdp.types import Transaction
from src.libs.rlp_little import extract_n_bytes_from_le_64_chunks_array
from src.hdp.utils import prepend_le_rlp_list_prefix, append_be_chunk
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
    const MAX_FEE_PER_BLOB_GAS = 13;
    const BLOB_VERSIONED_HASHES = 14;
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

    func get_field_by_index{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
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

    func get_felt_field_by_index{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
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
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
    }(tx: Transaction) -> felt {
        alloc_locals;

        let (tx_payload, tx_payload_len, tx_payload_bytes_len) = extract_tx_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(tx);

        let (
            encoded_tx_payload, encoded_tx_payload_len, encoded_tx_payload_bytes_len
        ) = rlp_encode_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(tx, tx_payload, tx_payload_len, tx_payload_bytes_len);

        let r_le = TransactionReader.get_field_by_index(tx, 7);
        let (r) = uint256_reverse_endian(r_le);
        let s_le = TransactionReader.get_field_by_index(tx, 8);
        let (s) = uint256_reverse_endian(s_le);

        local v_final: felt;
        let v_le = TransactionReader.get_field_by_index(tx, 6);
        let (v) = uint256_reverse_endian(v_le);

        // ToDo: add chain_id check here. Also only for valid hardforks.
        // ToDo: figure out why ecrecover precompile does v - 27
        %{
            #print("V:", hex(ids.v.low), hex(ids.v.high))
            if ids.v.low < 2:
                ids.v_final = ids.v.low
            elif ids.v.low % 2 == 1:
                ids.v_final = 0
            else:
                ids.v_final = 1

            #print("V_final:", ids.v_final)
        %}

        let (big_r) = uint256_to_bigint(r);
        let (big_s) = uint256_to_bigint(s);

        // Now we hash this reencoded transaction, which is what the sender has signed in the first place
        let (msg_hash) = keccak_bigend(encoded_tx_payload, encoded_tx_payload_bytes_len);
        let (big_msg_hash) = uint256_to_bigint(msg_hash);
        //%{ print("msg_hash:", hex(ids.msg_hash.low), hex(ids.msg_hash.high)) %}
        let (pub) = recover_public_key(big_msg_hash, big_r, big_s, v_final);

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

        // %{ print("Address:", hex(ids.address)) %}

        return (address);
    }

    func extract_tx_payload{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction
    ) -> (tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt) {
        let tx_params_bytes_len = tx.bytes_len - 67;  // 65 bytes for signature, 2 for s + r prefix

        // since the TX doesnt contain the list prefix, we simply retrieve the bytes, ignoring the signature ones
        let (tx_params, tx_params_len) = extract_n_bytes_from_le_64_chunks_array(
            array=tx.rlp,
            start_word=0,
            start_offset=0,
            n_bytes=tx_params_bytes_len,
            pow2_array=pow2_array,
        );

        // ToDo: Compatiblility with pre-eip155 transactions
        if (tx.type == 0) {
            // ToDo: need to integrate chain_id
            let eip155 = 0x018080;
            let eip155_bytes_len = 3;

            let (tx_payload, tx_payload_len, tx_payload_bytes_len) = append_be_chunk{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
            }(tx_params, tx_params_bytes_len, eip155, eip155_bytes_len);

            return (tx_payload, tx_payload_len, tx_payload_bytes_len);
        } else {
            return (tx_params, tx_params_len, tx_params_bytes_len);
        }
    }

    func rlp_encode_payload{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx: Transaction, tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt
    ) -> (signed_payload: felt*, signed_payload_len: felt, signed_payload_bytes_len: felt) {
        alloc_locals;
        local prefix: felt;
        local prefix_bytes_len: felt;
        local genesis_type: felt;
        %{
            from tools.py.utils import (
                reverse_endian,
                int_get_bytes_len,
                bytes_to_8_bytes_chunks_little
            )

            # We now need to generate the rlp prefix in LE.
            # This should be fine as a hint, as we are only adding formatting, not actual tx content
            # !!!!!! ATTENTION !!!!! This is actually not fine in a hint. We can inject malicious prefixes, which will cause ecrecover to derive a different address.
            if ids.tx_payload_bytes_len < 55:
                prefix = 0xc0 + ids.tx_payload_bytes_len
            else:
             #   print("tx_payload_len:", ids.tx_payload_len)
                len_len_bytes = int_get_bytes_len(ids.tx_payload_bytes_len)
                rlp_id = 0xf7 + len_len_bytes
                prefix = (rlp_id << (8 * len_len_bytes)) | ids.tx_payload_bytes_len

            # Prepend tx type if not genesis, and reverse endianess
            if(ids.tx.type == 0):
                ids.genesis_type = 1
                ids.prefix = reverse_endian(prefix)
            else:
                ids.genesis_type = 0
                ids.prefix = reverse_endian(ids.tx.type << (8 * int_get_bytes_len(prefix)) | prefix)

            ids.prefix_bytes_len = int_get_bytes_len(ids.prefix)
        %}

        if (genesis_type == 1) {
            assert tx.type = 0;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            assert [range_check_ptr] = tx.type - 1;
            tempvar range_check_ptr = range_check_ptr + 1;
        }

        // We have generated the RLP prefix in a hint, now we need to shift all values to fit the LE 64bit array format
        let (encoded_tx, encoded_tx_len) = prepend_le_rlp_list_prefix(
            offset=prefix_bytes_len, prefix=prefix, rlp=tx_payload, rlp_len=tx_payload_len
        );
        let encoded_tx_bytes_len = tx_payload_bytes_len + prefix_bytes_len;

        return (encoded_tx, encoded_tx_len, encoded_tx_bytes_len);
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

    // Legacy:
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
