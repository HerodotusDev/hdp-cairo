from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian, felt_to_uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak_bigend
from starkware.cairo.common.cairo_secp.bigint import uint256_to_bigint
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak
from starkware.cairo.common.cairo_secp.signature import (
    recover_public_key,
    public_key_point_to_eth_address,
)

from packages.eth_essentials.lib.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

from src.utils.rlp import (
    rlp_list_retrieve,
    le_chunks_to_uint256,
    prepend_le_chunks,
    append_be_chunk,
    get_rlp_list_meta,
    get_rlp_list_bytes_len,
    le_chunks_to_be_uint256,
)
from src.types import ChainInfo
from src.utils.utils import get_felt_bytes_len, reverse_chunk_endianess

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
    const TX_TYPE = 15;
    const SENDER = 16;
}

namespace TransactionType {
    const LEGACY = 0;
    const EIP2930 = 1;
    const EIP1559 = 2;
    const EIP4844 = 3;
}

namespace TransactionDecoder {

    // Returns the TX field as BE uint256
    func get_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*, chain_info: ChainInfo}(
        rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt
    ) -> Uint256 {
        alloc_locals;

        if (field == TransactionField.TX_TYPE) {
            return (Uint256(low=tx_type, high=0));
        }

        if (field == TransactionField.SENDER) {
            let sender_felt = TransactionSender.derive(rlp, rlp_start_offset, tx_type);
            let result = felt_to_uint256(sender_felt);
            return result;
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

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);
        let field_index = TxTypeFieldMap.get_field_index(tx_type, field);

        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field_index, value_start_offset, 0);
        let result = le_chunks_to_be_uint256(res, res_len, bytes_len);
        return result;
    }

    func get_field_and_bytes_len{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt
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

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);
        let field_index = TxTypeFieldMap.get_field_index(tx_type, field);

        let (local res, res_len, bytes_len) = rlp_list_retrieve(
            rlp, field_index, value_start_offset, 0
        );
        let value = le_chunks_to_uint256(res, res_len, bytes_len);
        return (value=value, bytes_len=bytes_len);
    }

    func get_felt_field{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*, field: felt, rlp_start_offset: felt, tx_type: felt
    ) -> (value: felt*, value_len: felt, bytes_len: felt) {
        alloc_locals;

        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);
        let field_index = TxTypeFieldMap.get_field_index(tx_type, field);

        let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, field_index, value_start_offset, 0);

        return (res, res_len, bytes_len);
    }

    // Opens the EIP-2718 transaction envelope. It returns the transaction type and the index where the RLP-encoded payload starts.
    // Inputs:
    // - item: The eveloped transaction
    // Outputs:
    // - tx_type: The type of the transaction
    // - rlp_start_offset: The index where the RLP-encoded payload starts
    func open_tx_envelope{range_check_ptr, pow2_array: felt*, bitwise_ptr: BitwiseBuiltin*}(
        item: felt*
    ) -> (tx_type: felt, rlp_start_offset: felt) {
        alloc_locals;

        let first_byte = extract_byte_at_pos(item[0], 0, pow2_array);
        let second_byte = extract_byte_at_pos(item[0], 1, pow2_array);

        local has_type_prefix: felt;
        %{
            # typed transactions have a type prefix in this range [1, 3]
            if 0x0 < ids.first_byte < 0x04:
                ids.has_type_prefix = 1
            else:
                ids.has_type_prefix = 0
        %}

        if (has_type_prefix == 1) {
            assert [range_check_ptr] = 0x3 - first_byte;
            assert [range_check_ptr + 1] = first_byte - 1;
            assert [range_check_ptr + 2] = 0xff - second_byte;
            assert [range_check_ptr + 3] = second_byte - 0xf7;

            tempvar range_check_ptr = range_check_ptr + 4;
            return (tx_type=first_byte, rlp_start_offset=1);
        } else {
            // Legacy transactions must start with long list prefix
            assert [range_check_ptr] = 0xff - first_byte;
            assert [range_check_ptr + 1] = first_byte - 0xf7;

            tempvar range_check_ptr = range_check_ptr + 2;
            return (tx_type=0, rlp_start_offset=0);
        }
    }
}

// Deriving the sender is an expensive operation, as it requires the recovery of the public key from the signature.
namespace TransactionSender {
    // Derives the sender of a transaction
    // This function call is very expensive, costing around 205k steps to run.
    // Inputs:
    //     tx: Transaction - The transaction object
    // Output:
    //     felt - The address of the sender, in BE
    func derive{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        keccak_ptr: KeccakBuiltin*,
        chain_info: ChainInfo,
    }(rlp: felt*, rlp_start_offset: felt, tx_type: felt) -> felt {
        alloc_locals;

        let v = TransactionDecoder.get_field(rlp, TransactionField.V, rlp_start_offset, tx_type);
        let (v_norm, is_eip155) = normalize_v{
            range_check_ptr=range_check_ptr, chain_info=chain_info
        }(tx_type, v);

        let (r_le, r_bytes_len) = TransactionDecoder.get_field_and_bytes_len(
            rlp, TransactionField.R, rlp_start_offset, tx_type
        );
        let (r) = uint256_reverse_endian(r_le);
        let (s_le, s_bytes_len) = TransactionDecoder.get_field_and_bytes_len(
            rlp, TransactionField.S, rlp_start_offset, tx_type
        );
        let (s) = uint256_reverse_endian(s_le);

        // Step 1: Unpack the RLP list and omit signature parameters
        let (tx_payload, tx_payload_len, tx_payload_bytes_len) = extract_tx_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(rlp, rlp_start_offset, r_bytes_len + s_bytes_len + 3, is_eip155);  // + 2 for s + r prefix, +1 for v

        // Step 2: RLP encode the TX params to create the signing payload and add TX type prefix
        let (
            encoded_tx_payload, encoded_tx_payload_len, encoded_tx_payload_bytes_len
        ) = encode_signing_payload{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, pow2_array=pow2_array
        }(tx_type, tx_payload, tx_payload_len, tx_payload_bytes_len);

        // Step 3: Calculate the keccak hash of the encoded tx payload
        let (msg_hash) = keccak_bigend(encoded_tx_payload, encoded_tx_payload_bytes_len);

        // Step 4:  Recover the public key from the signature
        let (big_r) = uint256_to_bigint(r);
        let (big_s) = uint256_to_bigint(s);
        let (big_msg_hash) = uint256_to_bigint(msg_hash);
        let (pub) = recover_public_key(big_msg_hash, big_r, big_s, v_norm);

        local address: felt;
        let (keccak_ptr_seg: felt*) = alloc();
        local keccak_ptr_seg_start: felt* = keccak_ptr_seg;

        // Step 5: Calculate the public address from the public key
        with keccak_ptr_seg {
            let (local public_address) = public_key_point_to_eth_address{
                range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, keccak_ptr=keccak_ptr_seg
            }(pub);

            assert address = public_address;
            finalize_keccak(keccak_ptr_start=keccak_ptr_seg_start, keccak_ptr_end=keccak_ptr_seg);
        }

        return (address);
    }

    // Extracts the transaction parameters from the RLP encoded transaction and omits the signature parameters
    // The RLP prefix is also removed
    func extract_tx_payload{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, chain_info: ChainInfo
    }(rlp: felt*, rlp_start_offset: felt, sig_bytes_len: felt, is_eip155: felt) -> (
        tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt
    ) {
        alloc_locals;

        // Calculate the rlp bytes length. The version prefix is ignored here
        let (rlp_bytes_len) = get_rlp_list_bytes_len(rlp, rlp_start_offset);
        let tx_params_bytes_len = rlp_bytes_len - sig_bytes_len;

        // retrieve the start index of the values (without list prefix)
        let (value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);

        // Now we cut the TX params from the rlp
        let (tx_params, tx_params_len) = extract_n_bytes_from_le_64_chunks_array(
            array=rlp,
            start_word=0,
            start_offset=value_start_offset,
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

    // Computes the RLP prefix for the transactions params and prepends the tx type prefix. The resulting rlp chunks are the signing payload
    // Inputs:
    //     tx: Transaction - The transaction object
    //     tx_payload: felt* - The RLP encoded transaction parameters. This does not include the RLP list prefix.
    //     tx_payload_len: felt - The number of 64bit chunks in the tx_payload
    //     tx_payload_bytes_len: felt - The number of bytes in the tx_payload
    // Outputs:
    //     signed_payload: felt* - The encoded transaction payload in the form that the sender has signed
    //     signed_payload_len: felt - The number of 64bit chunks in the signed_payload
    //     signed_payload_bytes_len: felt - The number of bytes in the signed_payload
    func encode_signing_payload{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        tx_type: felt, tx_payload: felt*, tx_payload_len: felt, tx_payload_bytes_len: felt
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
            tempvar pow2_array = pow2_array;
            tempvar range_check_ptr = range_check_ptr + 1;
        } else {
            // Calculate the prefix for an RLP long list
            let len_len = get_felt_bytes_len(tx_payload_bytes_len);
            assert [range_check_ptr] = tx_payload_bytes_len - 56;
            assert prefix = (0xf7 + len_len) * pow2_array[8 * len_len] + tx_payload_bytes_len;
            assert current_len = len_len + 1;
            tempvar pow2_array = pow2_array;
            tempvar range_check_ptr = range_check_ptr + 1;
        }
        let pow2_array = pow2_array;
        local typed_prefix: felt;
        if (tx_type == TransactionType.LEGACY) {
            // Legacy txs have no type prefix
            assert prefix_bytes_len = current_len;
            let le_prefix = reverse_chunk_endianess(prefix, prefix_bytes_len);
            assert typed_prefix = le_prefix;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            // All txs past EIP155 have a type prefix
            assert [range_check_ptr] = tx_type - 1;
            tempvar range_check_ptr = range_check_ptr + 1;
            assert prefix_bytes_len = current_len + 1;

            // prepend the tx type to the prefix and convert to LE
            let be_typed_prefix = tx_type * pow2_array[8 * current_len] + prefix;
            let le_typed_prefix = reverse_chunk_endianess(be_typed_prefix, prefix_bytes_len);

            assert typed_prefix = le_typed_prefix;
            tempvar range_check_ptr = range_check_ptr;
        }

        let encoded_tx_bytes_len = tx_payload_bytes_len + prefix_bytes_len;
        let (encoded_tx, encoded_tx_len) = prepend_le_chunks(
            item_bytes_len=prefix_bytes_len,
            item=typed_prefix,
            rlp=tx_payload,
            rlp_len=tx_payload_len,
            expected_bytes_len=encoded_tx_bytes_len,
        );

        return (encoded_tx, encoded_tx_len, encoded_tx_bytes_len);
    }

    // The extract the public key of the sende, we need to normalize the signatures v parameter.
    // For legacy transactions, we also need to check if it is an EIP155 transaction. This can be derived by the V parameter.
    func normalize_v{range_check_ptr, chain_info: ChainInfo}(tx_type: felt, v: Uint256) -> (
        v_norm: felt, is_eip155: felt
    ) {
        alloc_locals;

        local is_eip155: felt;
        local v_norm: felt;
        %{ ids.is_eip155 = 1 if ids.chain_info.id * 2 + 35 <= ids.v.low <= ids.chain_info.id * 2 + 36 else 0 %}
        // a tx uses EIP155 if the V value is in the range of [chain_id * 2 + 35, chain_id * 2 + 36]
        if (is_eip155 == 1) {
            assert [range_check_ptr] = (chain_info.id * 2 + 36) - v.low;
            assert [range_check_ptr + 1] = v.low - (chain_info.id * 2 + 35);
            assert tx_type = TransactionType.LEGACY;
            assert v_norm = v.low - (chain_info.id * 2 + 35);
        } else {
            // if its not eip155, V must be smaller
            assert [range_check_ptr] = (chain_info.id * 2 + 35) - v.low;
            if (tx_type == TransactionType.LEGACY) {
                assert [range_check_ptr + 1] = v.low - 27;  // In theory, this should never fail
                assert v_norm = v.low - 27;
            } else {
                assert [range_check_ptr + 1] = 1 - v.low;  // In theory, this should never fail
                assert v_norm = v.low;
            }
        }
        tempvar range_check_ptr = range_check_ptr + 2;
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
