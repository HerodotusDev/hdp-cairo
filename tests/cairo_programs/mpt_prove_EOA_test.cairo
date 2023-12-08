%builtins output range_check bitwise keccak

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.math import unsigned_div_rem as felt_divmod
from starkware.cairo.common.registers import get_fp_and_pc

from src.libs.utils import pow2alloc127, word_reverse_endian_64, uint256_add
from src.libs.block_header import extract_state_root_little
from src.libs.rlp_little import (
    extract_byte_at_pos,
    get_0xff_mask,
    extract_n_bytes_at_pos,
    extract_nibble_at_byte_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

const NODE_TYPE_LEAF = 1;
const NODE_TYPE_EXTENSION = 2;
const NODE_TYPE_BRANCH = 3;

// BLANK HASH BIG = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
// BLANK HASH LITTLE = 5094972239999916

func main{
    output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;
    local state_root_little: Uint256;
    let (account_proof: felt***) = alloc();
    local account_proof_len: felt*;
    let (account_proof_bytes_len: felt*) = alloc();
    let (address_64_little: felt*) = alloc();
    %{
        from tools.py.fetch_block_headers import fetch_blocks_from_rpc_no_async
        from tools.py.utils import bytes_to_8_bytes_chunks_little, split_128, reverse_endian_256, bytes_to_8_bytes_chunks
        from dotenv import load_dotenv
        import os
        from web3 import Web3
        from eth_utils import keccak
        import pickle
        load_dotenv()
        RPC_URL = os.getenv('RPC_URL_MAINNET')

        offline=True
        if not offline:
            w3 = Web3(Web3.HTTPProvider(RPC_URL))
            block = get_block_header(block_number)
            pickle.dump(block, open("block.pickle", "wb"))

        address = 0xd3cda913deb6f67967b99d67acdfa1712c293601
        block_number = 81326
        def get_block_header(number: int):
            blocks = fetch_blocks_from_rpc_no_async(number + 1, number - 1, RPC_URL)
            block = blocks[1]
            assert block.number == number, f"Block number mismatch {block.number} != {number}"
            return block

        block=pickle.load(open("block.pickle", "rb"))

        state_root = int(block.stateRoot.hex(),16)
        print(state_root.to_bytes(32, 'big'))
        state_root_little = split_128(int.from_bytes(state_root.to_bytes(32, 'big'), 'little'))
        ids.state_root_little.low = state_root_little[0]
        ids.state_root_little.high = state_root_little[1]

        if not offline:
            proof = w3.eth.get_proof(
                w3.toChecksumAddress(address),
                [0],
                block_number,
            )
            pickle.dump(proof, open("proof.pickle", "wb"))

        proof = pickle.load(open("proof.pickle", "rb"))

        assert keccak(proof['accountProof'][0]) == state_root.to_bytes(32, 'big')
        print(proof)
        print(state_root)
        print(keccak(proof['accountProof'][0]))
        accountProofbytes = [node for node in proof['accountProof']]
        assert keccak(accountProofbytes[0]) == state_root.to_bytes(32, 'big'), f"keccak mismatch {keccak(accountProofbytes[0])} != {state_root.to_bytes(32, 'big')}"
        accountProofbytes_len = [len(byte_proof) for byte_proof in accountProofbytes]
        accountProof = [bytes_to_8_bytes_chunks_little(node) for node in accountProofbytes]
        accountProof_big = [bytes_to_8_bytes_chunks(node) for node in accountProofbytes]
        print(accountProofbytes)
        print(accountProofbytes_len)
        print(accountProof)
        print(accountProof_big)
        segments.write_arg(ids.account_proof, accountProof)
        segments.write_arg(ids.account_proof_bytes_len, accountProofbytes_len)
        ids.account_proof_len = len(accountProof)
        segments.write_arg(ids.address_64_little, bytes_to_8_bytes_chunks_little(address.to_bytes(20, 'big')))
    %}
    let (pow2_array: felt*) = pow2alloc127();
    let (keccak_first_node: Uint256) = keccak(account_proof[0], account_proof_bytes_len[0]);
    // %{ print((ids.keccak_first_node.low + ids.keccak_first_node.high*2**128).to_bytes(32, "big")) %}
    // %{ print((ids.keccak_first_node.low + ids.keccak_first_node.high*2**128).to_bytes(32, "little")) %}

    assert keccak_first_node.low - state_root_little.low = 0;
    assert keccak_first_node.high - state_root_little.high = 0;

    let second_node = account_proof[1];

    // with key, key_nibble_offset {
    //     let hash = decode_non_leaf_node(second_node, account_proof_bytes_len[0], 0);
    // }
    %{ print(0, "\n") %}
    decode_node_list_lazy(account_proof[0], account_proof_bytes_len[0], pow2_array, 0);
    %{ print(1, "\n") %}
    decode_node_list_lazy(account_proof[1], account_proof_bytes_len[1], pow2_array, 0);
    %{ print(2, "\n") %}
    decode_node_list_lazy(account_proof[2], account_proof_bytes_len[2], pow2_array, 0);
    %{ print(3, "\n") %}
    decode_node_list_lazy(account_proof[3], account_proof_bytes_len[3], pow2_array, 0);
    %{ print(4, "\n") %}
    decode_node_list_lazy(account_proof[4], account_proof_bytes_len[4], pow2_array, 1);
    return ();
}

func verify_account_proof{
    output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}(
    state_root_little: Uint256,
    account_proof: felt***,
    account_proof_bytes_len: felt*,
    account_proof_len: felt,
    address_64_little: felt*,
    pow2_array: felt*,
) {
    alloc_locals;
    let (key) = keccak(address_64_little, 20);
    %{ print(f"key: {hex(ids.key.low + ids.key.high*2**128)}") %}
    tempvar accumulated_key: Uint256 = Uint256(0, 0);
    let (local extracted_hashes: Uint256*) = alloc();
    
    tempvar node_index = 0;
    tempvar nodes_to_process = account_proof_len;
    extract_loop:
    jmp init_hash_loop;

    init_hash_loop:
    tempvar index = nodes_to_process - 1;


    hash_loop:


}

func decode_node_list_lazy{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*, bytes_len: felt, pow2_array: felt*, last_node: felt
) ->( {
    alloc_locals;
    let list_prefix = extract_byte_at_pos(rlp[0], 0, pow2_array);
    local long_short_list: felt;  // 0 for short, !=0 for long.
    %{
        if 0xc0 <= ids.list_prefix <= 0xf7:
            ids.long_short_list = 0
            print("List type : short")
        elif 0xf8 <= ids.list_prefix <= 0xff:
            ids.long_short_list = 1
            print("List type: long")
        else:
            print("Not a list.")
    %}
    local first_item_start_offset: felt;
    local list_len: felt;  // Bytes length of the list. (not including the prefix)

    if (long_short_list != 0) {
        // Long list.
        assert [range_check_ptr] = list_prefix - 0xf8;
        assert [range_check_ptr + 1] = 0xff - list_prefix;
        let len_len = list_prefix - 0xf7;
        assert first_item_start_offset = 1 + len_len;
        assert list_len = bytes_len - len_len - 1;
    } else {
        // Short list.
        assert [range_check_ptr] = list_prefix - 0xc0;
        assert [range_check_ptr + 1] = 0xf7 - list_prefix;
        assert first_item_start_offset = 1;
        assert list_len = list_prefix - 0xc0;
    }
    // At this point, if input is neither a long nor a short list, then the range check will fail.
    %{ print("list_len", ids.list_len) %}
    %{ print("first word", memory[ids.rlp]) %}
    assert [range_check_ptr + 2] = 7 - first_item_start_offset;
    // We now need to differentiate between the type of nodes: extension/leaf or branch.

    %{ print("first item starts at byte", ids.first_item_start_offset) %}
    let first_item_prefix = extract_byte_at_pos(rlp[0], first_item_start_offset, pow2_array);

    %{ print("First item prefix", hex(ids.first_item_prefix)) %}
    // Regardless of leaf, extension or branch, the first item should always be less than 32 bytes so a short string :
    // 0-55 bytes string long
    // (range [0x80, 0xb7] (dec. [128, 183])).
    assert [range_check_ptr + 3] = first_item_prefix - 0x80;
    assert [range_check_ptr + 4] = 0xb7 - first_item_prefix;
    tempvar range_check_ptr = range_check_ptr + 5;
    tempvar first_item_len = first_item_prefix - 0x80;
    tempvar second_item_starts_at_byte = first_item_start_offset + 1 + first_item_len;
    %{ print("first item len:", ids.first_item_len, "bytes") %}
    %{ print("second_item_starts_at_byte", ids.second_item_starts_at_byte) %}
    let (second_item_starts_at_word, second_item_start_offset) = felt_divmod(
        second_item_starts_at_byte, 8
    );
    %{ print("second_item_starts_at_word", ids.second_item_starts_at_word) %}
    %{ print("second_item_start_offset", ids.second_item_start_offset) %}
    %{ print("second_item_first_word", memory[ids.rlp + ids.second_item_starts_at_word]) %}

    let second_item_prefix = extract_byte_at_pos(
        rlp[second_item_starts_at_word], second_item_start_offset, pow2_array
    );
    %{ print("second_item_prefix", hex(ids.second_item_prefix)) %}
    local second_item_type: felt;
    %{
        if 0x00 <= ids.second_item_prefix <= 0x7f:
            ids.second_item_type = 0
            print(f"2nd item : single byte")
        elif 0x80 <= ids.second_item_prefix <= 0xb7:
            ids.second_item_type = 1
            print(f"2nd item : short string {ids.second_item_prefix - 0x80} bytes")
        elif 0xb8 <= ids.second_item_prefix <= 0xbf:
            ids.second_item_type = 2
            print(f"2nd item : long string (len_len {ids.second_item_prefix - 0xb7} bytes)")
        else:
            print(f"2nd item : unknown type {ids.second_item_prefix}")
    %}

    local second_item_bytes_len;
    local second_item_len_len;
    local third_item_starts_at_byte;
    local range_check_ptr_f;
    local bitwise_ptr_f: BitwiseBuiltin*;
    if (second_item_type == 0) {
        // Single byte.
        assert [range_check_ptr] = 0x7f - second_item_prefix;
        assert second_item_bytes_len = 1;
        assert third_item_starts_at_byte = second_item_starts_at_byte + second_item_bytes_len;
        assert range_check_ptr_f = range_check_ptr + 1;
        assert bitwise_ptr_f = bitwise_ptr;
    } else {
        if (second_item_type == 1) {
            // Short string.
            assert [range_check_ptr] = second_item_prefix - 0x80;
            assert [range_check_ptr + 1] = 0xb7 - second_item_prefix;
            assert second_item_bytes_len = second_item_prefix - 0x80;
            assert third_item_starts_at_byte = second_item_starts_at_byte + 1 +
                second_item_bytes_len;
            assert range_check_ptr_f = range_check_ptr + 2;
            assert bitwise_ptr_f = bitwise_ptr;
        } else {
            // Long string.
            assert [range_check_ptr] = second_item_prefix - 0xb8;
            assert [range_check_ptr + 1] = 0xbf - second_item_prefix;

            let len_len = second_item_prefix - 0xb7;
            tempvar end_of_len_virtual_offset = second_item_start_offset + 1 + len_len;

            local second_item_long_string_len_fits_into_current_word: felt;
            %{ ids.second_item_long_string_len_fits_into_current_word = (7 - ids.end_of_len_virtual_offset) >= 0 %}

            if (second_item_long_string_len_fits_into_current_word != 0) {
                %{ print(f"Len len {ids.len_len} fits into current word.") %}
                // len_len bytes can be extracted from the current word.
                assert [range_check_ptr + 2] = 7 - end_of_len_virtual_offset;

                if (len_len == 1) {
                    // No need to reverse endian since it's a single byte.
                    let second_item_long_string_len = extract_byte_at_pos(
                        rlp[second_item_starts_at_word], second_item_start_offset + 1, pow2_array
                    );
                    assert second_item_bytes_len = second_item_long_string_len;
                    tempvar bitwise_ptr = bitwise_ptr;
                } else {
                    let second_item_long_string_len_little = extract_n_bytes_at_pos(
                        rlp[second_item_starts_at_word],
                        second_item_start_offset,
                        len_len,
                        pow2_array,
                    );
                    let (tmp) = word_reverse_endian_64(second_item_long_string_len_little);
                    assert second_item_bytes_len = tmp / pow2_array[64 - 8 * len_len];
                    tempvar bitwise_ptr = bitwise_ptr;
                }

                %{ print(f"second_item_long_string_len : {ids.second_item_bytes_len} bytes") %}
                assert third_item_starts_at_byte = second_item_starts_at_byte + 1 + len_len +
                    second_item_bytes_len;
                assert range_check_ptr_f = range_check_ptr + 3;
                assert bitwise_ptr_f = bitwise_ptr;
            } else {
                %{ print("Len len doesn't fit into current word.") %}
                // Very unlikely. But fix anyway.

                let range_check_ptr = range_check_ptr;

                assert [range_check_ptr + 2] = end_of_len_virtual_offset - 8;
                let n_bytes_to_extract_from_next_word = end_of_len_virtual_offset - 8;  // end_of_len_virtual_offset%8
                let n_bytes_to_extract_from_current_word = len_len -
                    n_bytes_to_extract_from_next_word;
                assert len_len = n_bytes_to_extract_from_next_word +
                    n_bytes_to_extract_from_current_word;

                // if (second_item_start_offset + len_len == 8) {
                // }
                assert range_check_ptr_f = range_check_ptr + 3;
                assert bitwise_ptr_f = bitwise_ptr;
            }
        }
    }
    let range_check_ptr = range_check_ptr_f;
    let bitwise_ptr = bitwise_ptr_f;
    %{ print(f"second_item_bytes_len : {ids.second_item_bytes_len} bytes") %}

    %{ print(f"third item starts at byte {ids.third_item_starts_at_byte}") %}

    local bitwise_ptr_f: BitwiseBuiltin*;
    local range_check_ptr_f;
    if (third_item_starts_at_byte == bytes_len) {
        // Node's list has only 2 items : it's a leaf or an extension.
        // Regardless, we need to decode the first item (key or key_end) and the second item (hash or value).

        // get the first item's prefix:
        // actual item value starts at byte first_item_start_offset + 1 (after the prefix)
        // Get the very first nibble.
        let first_item_prefix = extract_nibble_at_byte_pos(
            rlp[0], first_item_start_offset + 1, 0, pow2_array
        );
        %{
            prefix = ids.first_item_prefix
            if prefix == 0:
                print("First item is an extension node, even number of nibbles")
            elif prefix == 1:
                print("First item is an extension node, odd number of nibbles")
            elif prefix == 2:
                print("First item is a leaf node, even number of nibbles")
            elif prefix == 3:
                print("First item is a leaf node, odd number of nibbles")
            else:
                raise Exception(f"Unknown prefix {prefix} for list with 2 items")
        %}
        let (start_word, start_offset) = felt_divmod(first_item_start_offset + 2, 8);
        let extracted_key_subset = extract_n_bytes_from_le_64_chunks_array(
            rlp, start_word, start_offset, first_item_len - 1, pow2_array
        );
        %{
        %}

        assert bitwise_ptr_f = bitwise_ptr;
        assert range_check_ptr_f = range_check_ptr;
        tempvar first_item_bytes_acc = 8 - (first_item_start_offset + 1);
    } else {
        // Node has more than 2 items : it's a branch.
        if (last_node != 0) {
            // Last node in the proof. We need to extract the last item (17th).
            
            return (Uint256(0, 0));
        } else {
            // Not the last node in the proof. We need to extract the hash corresponding to the current nibble.
        }
        assert bitwise_ptr_f = bitwise_ptr;
        assert range_check_ptr_f = range_check_ptr;
    }

    let bitwise_ptr = bitwise_ptr_f;
    let range_check_ptr = range_check_ptr_f;
    return ();
}

func jump_till_element_at_index{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    rlp: felt*, current_byte_index: felt
) {
    alloc_locals;

    return ();
}
