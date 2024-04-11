from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.hdp.rlp import retrieve_from_rlp_list_via_idx, le_u64_array_to_uint256
from starkware.cairo.common.cairo_secp.signature import recover_public_key, public_key_point_to_eth_address
from starkware.cairo.common.cairo_keccak.keccak import finalize_keccak

from src.hdp.types import Transaction
from src.libs.rlp_little import (
    extract_n_bytes_from_le_64_chunks_array
)
from src.hdp.utils import prepend_le_rlp_list_prefix, append_be_chunk
from starkware.cairo.common.cairo_secp.bigint import (
    BigInt3,
    uint256_to_bigint,
)

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

// Deriving the sender is an expensive operation, as it requires the recovery of the public key from the signature.
// For this reason, this logic is in its own namespace. 
namespace TransactionSender {
    func derive{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        keccak_ptr: KeccakBuiltin*
    } (tx: Transaction) -> felt {
        alloc_locals;

        let unsigned_tx_bytes_len = tx.bytes_len - 67; // 65 bytes for signature, 2 for s + r prefix

        // since the TX doesnt contain the list prefix, we simply retrieve the bytes, ignoring the signature ones
        let (unsigned_tx_rlp, unsigned_tx_rlp_len) = extract_n_bytes_from_le_64_chunks_array(
            array=tx.rlp,
            start_word=0,
            start_offset=0,
            n_bytes=unsigned_tx_bytes_len,
            pow2_array=pow2_array
        );

        %{
            print("Unsigned RLP:")
            print("UNsigned len:", ids.unsigned_tx_bytes_len)
            i = 0
            while(i < ids.unsigned_tx_rlp_len):
                print("encoded_tx[", i, "]:", hex(memory[ids.unsigned_tx_rlp + i]))
                i += 1
        
        %}

        local scoped_tx_bytes_len: felt;
        // ToDo: Add hardfork block height check also. Need to redo the tx type for this
        // if(tx.type == 0) {
            // ToDo: need to integrate chain_id
        let eip155 = 0x018080;
        let eip155_bytes_len = 3;

        let (appended, appeneded_len, appended_bytes_len) = append_be_chunk{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            pow2_array=pow2_array
        }(
            unsigned_tx_rlp,
            unsigned_tx_bytes_len,
            eip155,
            eip155_bytes_len,
        );

         %{
            print("Appended len:", ids.appeneded_len)
            print("Appended bytes len:", ids.appended_bytes_len)
            print("Appended RLP:")
            i = 0
            while(i < ids.appeneded_len):
                print("encoded_tx[", i, "]:", hex(memory[ids.appended + i]))
                i += 1
        
        %}

        local unsigned_prefix: felt;
        local unsigned_prefix_bytes_len: felt;
        local genesis_type: felt;
        let (padded: felt*) = alloc();
        %{  
            from tools.py.utils import (
                reverse_endian,
                int_get_bytes_len,
                bytes_to_8_bytes_chunks_little
            )

            # We now need to generate the rlp prefix in LE.
            # This should be fine as a hint, as we are only adding formatting, not actual tx content
            # !!!!!! ATTENTION !!!!! This is actually not fine in a hint. We can inject malicious prefixes, which will cause ecrecover to derive a different address.
            if ids.appended_bytes_len < 55:
                prefix = 0xc0 + ids.appended_bytes_len
            else:
                #print("appended_bytes_len:", ids.appended_bytes_len)
                len_len_bytes = int_get_bytes_len(ids.appended_bytes_len)
                rlp_id = 0xf7 + len_len_bytes
                prefix = (rlp_id << (8 * len_len_bytes)) | ids.appended_bytes_len

            #print("prefix:", hex(prefix))
            # Prepend tx type if not genesis, and reverse endianess
            if(ids.tx.type == 0):
                ids.genesis_type = 1
                ids.unsigned_prefix = reverse_endian(prefix)
            else:
                ids.genesis_type = 0
                ids.unsigned_prefix = reverse_endian(ids.tx.type << 8 | prefix)

            ids.unsigned_prefix_bytes_len = int_get_bytes_len(ids.unsigned_prefix)

            #padded_bytes = bytes.fromhex("e40285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d86480018080")
            #padded_rlp = bytes_to_8_bytes_chunks_little(padded_bytes)
            #segments.write_arg(ids.padded, padded_rlp)
            #print("prefix:", hex(ids.unsigned_prefix))
        %}

        if(genesis_type == 1) {
            assert tx.type = 0;
            tempvar range_check_ptr = range_check_ptr;
        } else {
            assert [range_check_ptr] = tx.type - 1;
            tempvar range_check_ptr = range_check_ptr + 1;
        }

        // We have generated the RLP prefix in a hint, now we need to shift all values to fit the LE 64bit array format
        let (encoded_tx, encoded_tx_len) = prepend_le_rlp_list_prefix(
            offset=unsigned_prefix_bytes_len,
            prefix=unsigned_prefix,
            rlp=appended,
            rlp_len=appeneded_len
        );
        let encoded_tx_bytes_len = appended_bytes_len + unsigned_prefix_bytes_len;

        %{
            i = 0
            print("Encoded RLP:")
            while(i < ids.encoded_tx_len):
                print("encoded_tx[", i, "]:", hex(memory[ids.encoded_tx + i]))
                i += 1
        
        %}

        let r = TransactionReader.get_field_by_index(tx, 7);
        let s = TransactionReader.get_field_by_index(tx, 8);

        %{
            print("R:", hex(ids.r.low), hex(ids.r.high))
            print("S:", hex(ids.s.low), hex(ids.s.high))
        
        %}

        local v_final: felt;
        let v = TransactionReader.get_field_by_index(tx, 6);
        // ToDo: add chain_id check here. Also only for valid hardforks.
        %{
            print("V:", hex(ids.v.low), hex(ids.v.high))
            if ids.v.low % 2 == 1:
                ids.v_final = 0
            else:
                ids.v_final = 1

            print("V_final:", ids.v_final)
        %}


        let (big_r) = uint256_to_bigint(r);
        let (big_s) = uint256_to_bigint(s);

        // Now we hash this reencoded transaction, which is what the sender has signed in the first place
        let (msg_hash) = keccak_bigend(encoded_tx, encoded_tx_bytes_len);
        let (big_msg_hash) = uint256_to_bigint(msg_hash);
        %{
            print("msg_hash:", hex(ids.msg_hash.low), hex(ids.msg_hash.high))
        %}
        let (pub) = recover_public_key(big_msg_hash, big_r, big_s, v_final);

        local address: felt;
        let (keccak_ptr_seg: felt*) = alloc();
        local keccak_ptr_seg_start: felt* = keccak_ptr_seg;

        with keccak_ptr_seg {
            let (local public_address) = public_key_point_to_eth_address{
                range_check_ptr=range_check_ptr,
                bitwise_ptr=bitwise_ptr,
                keccak_ptr=keccak_ptr_seg
            }(pub);

            assert address = public_address;
            finalize_keccak(keccak_ptr_start=keccak_ptr_seg_start, keccak_ptr_end=keccak_ptr_seg);
        }

        %{ print("Address:", hex(ids.address)) %}

        return (address);

        // return (address);
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


