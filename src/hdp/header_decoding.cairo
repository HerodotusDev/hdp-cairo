%builtins range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
// from starkware.cairo.common.math import unsigned_div_rem as felt_divmod
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.libs.utils import pow2alloc128
from src.libs.utils import felt_divmod
from src.libs.rlp_little import (
    extract_byte_at_pos,
    extract_n_bytes_from_le_64_chunks_array,
)

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let (values) = alloc();

    %{
        homestead = [
            '0x5ddb4b58a01802f9', '0x2b22a5f597fe744e', '0xadb6d02f32e13f53', '0x841922c3023fb03e', 
            '0x4dcc1da030b4c0e2', '0xb585ab7a5dc7dee8', '0x4512d31ad4ccb667', '0x42a1f013748a941b', 
            '0x652a944793d440fd', '0x90855c5bfcd5a4ac', '0x393541164dc3a690', '0xbdc34a6d06a02682', 
            '0x6496288b91023cc3', '0x6b4ecbe02d473dd8', '0x154a94aba4b3842d', '0xb2b5f499a08b6fd8', 
            '0x3f721588d9d81e2c', '0xf41c97d2e86f262c', '0xfbc70e8120c7a855', '0xb6ac5ca07d9d4d1b', 
            '0x1ab385d03d89d05', '0x83a92cd14fa08ac1', '0x82bdacf432323a72', '0x1b93d365bf973', '0x0', 
            '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', 
            '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', 
            '0x0', '0x0', '0x0', '0x0', '0x0', '0x83d134b417a11286', '0x83c4e74783318c11', '0xda07e75684e80301', '0x478405030183d798', '0x2e316f6787687465', '0x756e696c85312e35', '0x23b95b80bcbca078', '0x459e0d4bc4949e27', '0x8946403c4e4bf8a6', '0xd345e360101baf02', '0x128f9ad9b0881ea7', '0x105ad9']
        homestead = [int(val, 16) for val in homestead]
        segments.write_arg(ids.values, homestead)

        decoded = [
            # parent
            "0x584bdb5d4e74fe97f5a5222b533fe132 2fd0b6ad3eb03f02c3221984e2c0b430",
            # uncle
            "0x1dcc4de8dec75d7aab85b567b6ccd41a d312451b948a7413f0a142fd40d49347",
            # coinbase
            "0x2a65aca4d5fc5b5c 859090a6c34d1641 35398226",
            # state_root
            "0x066d4ac3bdc33c02918b289664d83d47 2de0cb4e6b2d84b3a4ab944a15d86f8b",
            # tx_root
            "0x99f4b5b22c1ed8d98815723f2c266fe8 d2971cf455a8c720810ec7fb1b4d9d7d",
            # receipts_root 
            "0x5cacb6059dd8035d38ab01c18aa04fd1 2ca983723a3232f4 acbd8273f95b363d",
            # logs_bloom
            "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            # difficulty
            "0x12a117b434d1",
            # number
            "0x118c31",
            # gas_limit
            "0x47e7c4",
            # gas_used
            "0x0103e8",
            # timestamp
            "0x56e707da",
            # extra_data
            "0xd783010305844765746887676f312e352e31856c696e7578",
            # mix_hash
            "0xbcbc805bb923279e94c44b0d9e45a6f84b4e3c40468902af1b1060e345d3a71e",
            # nonce
            "0xb0d99a8f12d95a10"
        ]

        def decode_len(byte):
            if(byte <= 0x7f): #[0x00, 0x7f]
                # single byte
                return 1
            elif (byte <= 0xb7): #[0x80, 0xb7]
                # string <= 55 bytes
                return byte - 80
            elif(byte <= 0xbf): #[0xb8, 0xbf]
                # string > 55 bytes
                return byte.next()
            elif(byte <= 0xf7): #[0xc0, 0xf7]
                # list <= 55 bytes
                return byte.next()
            else: #[0xf8, ...]
                # list > 55 bytes
                len_bytes_len = byte.next()
                return byte.get(len_bytes_len)

    %}

    let pow2_array: felt* = pow2alloc128();
    let tx_root = get_dynamic_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(values, 14);

    // %{
    //     print("tx_root: ", hex(ids.tx_root.low), hex(ids.tx_root.high))
    // %}

    let address = get_address_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(values, 2);

    let a0 = address[0];
    let a1 = address[1];
    let a2 = address[2];

    %{
        print("address: ", hex(ids.a0), hex(ids.a1), hex(ids.a2))
    %}

    return ();
}

func get_address_field{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(rlp: felt*, field: felt) -> felt* {
    if(field == 2){
        return get_address_value(rlp, 8, 6);
    }

    assert 1 = 0;

    let (val) = alloc();
    return (val);
}

func get_hash_field{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(rlp: felt*, field: felt) -> Uint256 {
    alloc_locals;
    
    //parent
    if(field == 0) {
        return get_hash_value(rlp, 0, 4);
    }
    if(field == 1){
        return get_hash_value(rlp, 4, 5);
    }
    if(field == 3){
        return get_hash_value(rlp, 11, 3);
    }
    if(field == 4){
        return get_hash_value(rlp, 15, 4);
    }
    if(field == 5){
        return get_hash_value(rlp, 19, 5);
    }

    // unknown field
    assert 1 = 0;

    return (Uint256(low=0, high=0));
}

func get_dynamic_field{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(rlp: felt*, field: felt) -> felt* {

    let start_byte = 448; // 20 + 5*32 + 256 + encoding bytes
    let field_idx = field - 7; // we have 7 static fields that we skip
    
    let (res, res_len, bytes_len) = retrieve_from_rlp_via_idx(
        rlp=rlp,
        value_idx=field_idx,
        item_starts_at_byte=start_byte,
        counter=0,
    );

    let r0 = res[0];

    %{
        print("res_len: ", ids.res_len)
        print("bytes_len: ", ids.bytes_len)
        print("res: ", hex(ids.r0))
    %}

    return (res);
}

func retrieve_from_rlp_via_idx{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
   
} ( rlp: felt*, value_idx: felt, item_starts_at_byte: felt, counter: felt) -> (res: felt*, res_len: felt, bytes_len: felt) {
    alloc_locals;

    let (item_starts_at_word, item_start_offset) = felt_divmod(
        item_starts_at_byte, 8
    );

    let current_item = extract_byte_at_pos(
        rlp[item_starts_at_word],
        item_start_offset,
        pow2_array
    );

    local item_has_prefix: felt;

    // We need to validate this hint via assert!!!
    %{
        # print("current_item", hex(ids.current_item))
        if ids.current_item < 0x80:
            ids.item_has_prefix = 0
        else:
            ids.item_has_prefix = 1
    %}

    local current_item_len: felt;

    if (item_has_prefix == 1) {
        assert [range_check_ptr] = current_item - 0x80; // validates item_has_prefix hint
        current_item_len = current_item - 0x80;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len + 1;
    } else {
        assert [range_check_ptr] = 0x7f - current_item; // validates item_has_prefix hint
        current_item_len = 1;
        tempvar next_item_starts_at_byte = item_starts_at_byte +  current_item_len;
    }

    let range_check_ptr = range_check_ptr + 1;
    

    // %{ print("next_item_starts_at_byte", ids.next_item_starts_at_byte) %}

    if (value_idx == counter) {
        // handle empty bytes case
        if(current_item_len == 0) {
            // %{ print("empty case") %}
            let (res: felt*) = alloc();
            assert res[0] = 0;
            return (res=res, res_len=1, bytes_len=1);
        } 

        // handle prefix case
        if (item_has_prefix == 1) {
            // %{ print("prefix case") %}
            let (word_idx, offset) = felt_divmod(
                item_starts_at_byte + 1, 8
            );
            
            let (res, res_len) = extract_n_bytes_from_le_64_chunks_array(
                array=rlp,
                start_word=word_idx,
                start_offset=offset,
                n_bytes=current_item_len,
                pow2_array=pow2_array
            );

            return (res=res, res_len=res_len, bytes_len=current_item_len);
        } else {
            // %{ print("single byte case") %}
            // handle single byte case
            let (res: felt*) = alloc();
            assert res[0] = current_item;
            return (res=res, res_len=1, bytes_len=1);
        }
    }

    return retrieve_from_rlp_via_idx(
        rlp=rlp,
        value_idx=value_idx,
        item_starts_at_byte=next_item_starts_at_byte,
        counter=counter+1,
    );
}


func get_hash_value{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*, word_idx: felt, offset: felt) -> Uint256 {
    let shifter = (8 - offset) * 8;
    let devisor = pow2_array[offset * 8];

    let rlp_0 = rlp[word_idx];
    let (rlp_0, thrash) = felt_divmod(rlp_0, devisor);
    let rlp_1 = rlp[word_idx + 1];
    let rlp_2 = rlp[word_idx + 2];
    let (rlp_2_left, rlp_2_right) = felt_divmod(rlp_2, devisor);
    let rlp_3 = rlp[word_idx + 3];
    let rlp_4 = rlp[word_idx + 4];
    let (tash, rlp_4) = felt_divmod(rlp_4, devisor);

    let res_low = rlp_2_right * pow2_array[shifter+ 64] + rlp_1 * pow2_array[shifter] + rlp_0;
    let res_high = rlp_4 * pow2_array[shifter + 64] + rlp_3 * pow2_array[shifter] + rlp_2_left;

    return (Uint256(low=res_low, high=res_high));
}

func get_address_value{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
} (rlp: felt*, word_idx: felt, offset: felt) -> felt* {
    let (addr) = alloc();

    let shifter = (8 - offset) * 8;
    let devisor = pow2_array[offset * 8];

    let rlp_0 = rlp[word_idx];
    let (rlp_0, thrash) = felt_divmod(rlp_0, devisor);
    let rlp_1 = rlp[word_idx + 1];
    let (rlp_1_left, rlp_1_right) = felt_divmod(rlp_1, devisor);
    assert [addr] = rlp_1_right * pow2_array[shifter] + rlp_0;

    let rlp_2 = rlp[word_idx + 2];
    let rlp_2_word = rlp_2;
    let (rlp_2_left, rlp_2_right) = felt_divmod(rlp_2, devisor);
    assert [addr + 1] = rlp_2_right * pow2_array[shifter] + rlp_1_left;

    let rlp_3 = rlp[word_idx + 3];
    let last_divisor = pow2_array[(offset - 4) * 8]; // address is 20 bytes, so we need to subtract 4 from the offset
    let (trash, rlp_3_right) = felt_divmod(rlp_3, last_divisor);
    assert [addr + 2] = rlp_3_right * pow2_array[shifter] + rlp_2_left;

    return (addr);
}