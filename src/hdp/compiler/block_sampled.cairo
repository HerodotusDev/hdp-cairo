%builtins range_check bitwise keccak

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bitwise import bitwise_xor
from src.libs.utils import word_reverse_endian_64, word_reverse_endian_16_RC
from src.hdp.types import BlockSampledHeader, BlockSampledAccount, BlockSampledAccountSlot

func hash_block_sampled{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
} (input: felt*, input_bytes_len: felt) -> (hash: Uint256) {
    alloc_locals;

    let (hash: Uint256) = keccak(input, input_bytes_len);

    %{
        print(f"hash_block_sampled: {hex(ids.hash.high)} {hex(ids.hash.low)}")
    %}

    return (hash=hash);
}

func decode_header_input{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(input: felt*, input_bytes_len: felt) -> BlockSampledHeader {
    alloc_locals;

    let (hash) = hash_block_sampled{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr   
    }(input=input, input_bytes_len=input_bytes_len);

    let (block_range_start, block_range_end, increment) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    let dyn_data = word_reverse_endian_16_RC([input + 24]);
    assert [range_check_ptr] = 0x01ff - dyn_data; // ensure header prop. max value = 0x01ff
    let range_check_ptr = range_check_ptr + 1;
    
    let property = dyn_data - 0x100; // bootleg bitshift, returns last byte, if range_check passes

    return (BlockSampledHeader(
        block_range_start=block_range_start,
        block_range_end=block_range_end,
        increment=increment,
        property=property,
        hash=hash
    ));
}

func decode_account_input{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(input: felt*, input_bytes_len: felt) -> BlockSampledAccount {
    alloc_locals;

    let (hash) = hash_block_sampled{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr   
    }(input=input, input_bytes_len=input_bytes_len);

    let (block_range_start, block_range_end, increment) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    let (id, address) = extract_id_and_address{
        bitwise_ptr=bitwise_ptr
    }(chunk_one=[input + 24], chunk_two=[input + 25], chunk_three=[input + 26]);

    assert id = 2; // enforces account type

    assert bitwise_ptr[0].x = [input + 26]; 
    assert bitwise_ptr[0].y = 0xff0000000000;
    tempvar property = bitwise_ptr[0].x_and_y / 0x10000000000;

    let bitwise_ptr = bitwise_ptr + BitwiseBuiltin.SIZE;

    return (BlockSampledAccount(
        block_range_start=block_range_start,
        block_range_end=block_range_end,
        increment=increment,
        address=address,
        property=property,
        hash=hash
    ));
}

func decode_slot_input{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}(input: felt*, input_bytes_len: felt) -> BlockSampledAccountSlot {
    alloc_locals;

    let (hash) = hash_block_sampled{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr   
    }(input=input, input_bytes_len=input_bytes_len);

    let (block_range_start, block_range_end, increment) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    let (id, address) = extract_id_and_address{
        bitwise_ptr=bitwise_ptr
    }(chunk_one=[input + 24], chunk_two=[input + 25], chunk_three=[input + 26]);

    assert id = 3; // enforces slot type
   
    let (slot: felt*) = alloc();

    extract_slot{
        bitwise_ptr=bitwise_ptr
    }(chunks=input + 26, idx=0, max_idx=4, slot=slot);


    return (BlockSampledAccountSlot(
        block_range_start=block_range_start,
        block_range_end=block_range_end,
        increment=increment,
        address=address,
        slot=slot,
        hash=hash
    ));
}


func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
    alloc_locals;

    local input_bytes_len: felt;
    local input: felt*;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks,
            bytes_to_8_bytes_chunks_little,
        )
        # header_prop
        #dl_bytes =bytes.fromhex("000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002010f000000000000000000000000000000000000000000000000000000000000")
        # account
        #dl_bytes = bytes.fromhex("000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000016025b38da6a701c568545dcfcb03fcb875f56beddc40300000000000000000000")

        # slot
        dl_bytes = bytes.fromhex("000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000035035b38da6a701c568545dcfcb03fcb875f56beddc4339bee47335c234581644b387f7f0d28db05ad5b092e1152fc70647d559cef220000000000000000000000")

        slot = bytes_to_8_bytes_chunks_little(bytes.fromhex("339bee47335c234581644b387f7f0d28db05ad5b092e1152fc70647d559cef22"))

        le_input = bytes_to_8_bytes_chunks_little(dl_bytes)

        be_input = bytes_to_8_bytes_chunks(dl_bytes)

        input_hex = [hex(val) for val in le_input]
        slot_hex = [hex(val) for val in slot]
        print(f"input: {input_hex}")
        print(f"slot: {slot_hex}")

        ids.input_bytes_len = len(dl_bytes)
        ids.input = segments.gen_arg(le_input)
    %}

    let header = decode_slot_input{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr
    }(input=input, input_bytes_len=input_bytes_len);

    return ();
}

func extract_slot{
    bitwise_ptr: BitwiseBuiltin*,
} (chunks: felt*, idx: felt, max_idx: felt, slot: felt*) {

    if(idx == max_idx) {
        return ();
    }

    assert bitwise_ptr[0].x = [chunks];
    assert bitwise_ptr[0].y = 0xffffff0000000000;
    tempvar least_sig_bytes = bitwise_ptr[0].x_and_y / 0x10000000000;

    assert bitwise_ptr[1].x = [chunks + 1]; 
    assert bitwise_ptr[1].y = 0x000000ffffffffff;
    tempvar most_significant_bytes = bitwise_ptr[1].x_and_y * 0x1000000;

    assert [slot + idx] = most_significant_bytes + least_sig_bytes;

    let slot_new = most_significant_bytes + least_sig_bytes;

    let bitwise_ptr = bitwise_ptr + 2 * BitwiseBuiltin.SIZE;
    return extract_slot{
        bitwise_ptr=bitwise_ptr
    }(chunks=chunks + 1, idx=idx + 1, max_idx=max_idx, slot=slot);
}

// Used for decoding the sampled property of block sampled headers. 
// Accepted types: Account or AccountSlot
// data must be encoded as follows: abi.encodePacked(uint8(2), account, ...);
// Inputs:
// 3x le 8-byte chunks
// Output:
// id: the ID of the sampled property (2 for Account, 3 for AccountSlot)
// address: le 8-byte chunks
func extract_id_and_address{
    bitwise_ptr: BitwiseBuiltin*,
} (chunk_one: felt, chunk_two: felt, chunk_three: felt) -> (id: felt, address: felt*) {
    
    let (address: felt*) = alloc();

    // Example Input + operations:         
    //  C1                   C2                   C3 
    // '561c706ada385b 02', '87cb3fb0fcdc45 85', '3c 4ddbe56 5f'
    //                  ^                    ^    ^           ^ 
    //                 ID + rem       prepend C1  rem          prepend C2

    // 1. Extract ID
    assert bitwise_ptr[0].x = chunk_one; 
    assert bitwise_ptr[0].y = 0x00000000000000ff;
    tempvar type_id = bitwise_ptr[0].x_and_y;

    // 2. Remove ID from C1 and right-shift
    let first_reduced = chunk_one - type_id;
    let first_reduced_div = first_reduced / 0x100;

    // 3. Extract last byte of C2 and prepend C1
    assert bitwise_ptr[1].x = chunk_two; 
    assert bitwise_ptr[1].y = 0x00000000000000ff;
    tempvar lsb_c2 = bitwise_ptr[1].x_and_y;
    assert [address] = (first_reduced_div) + (2 ** 56) * lsb_c2;

    // 4. Remove last byte of C2 and right-shift
    let second_reduced = chunk_two - lsb_c2;
    let second_reduced_div = second_reduced / 0x100;

    // 5. Extract last byte of C3 and prepend C2
    assert bitwise_ptr[2].x = chunk_three; 
    assert bitwise_ptr[2].y = 0x00000000000000ff;
    let shifted_prep_two = (2 ** 56) * bitwise_ptr[2].x_and_y;
    assert [address + 1] = (second_reduced_div) + shifted_prep_two;

    // 6. Extract remaining 4 address bytes and right-shift
    assert bitwise_ptr[3].x = chunk_three; 
    assert bitwise_ptr[3].y = 0x0ffffffff00;
    assert [address + 2] = bitwise_ptr[3].x_and_y / 0x100;

    let bitwise_ptr = bitwise_ptr + 4 * BitwiseBuiltin.SIZE;
    return (id=type_id, address=address);
}

func extract_constant_params{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
}(input: felt*) -> (block_range_start: felt, block_range_end: felt, increment: felt) {
    alloc_locals;
    // HeaderProp Input Layout:
    // 0-3: DatalakeCode.BlockSampled
    // 4-7: block_range_start
    // 8-11: block_range_end
    // 12-15: increment
    // 16-19: dynamic data offset
    // 20-23: dynamic data element count
    // 24-25: 01 + headerPropId
    assert [input + 3] = 0; // DatalakeCode.BlockSampled == 0

    assert [input + 6] = 0; // first 3 chunks of block_range_start should be 0
    let (block_range_start) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0; // first 3 chunks of block_range_end should be 0
    let (block_range_end) = word_reverse_endian_64([input + 11]);

    assert [input + 14] = 0; // first 3 chunks of increment should be 0
    let (increment) = word_reverse_endian_64([input + 15]);

    return (block_range_start=block_range_start, block_range_end=block_range_end, increment=increment);
}