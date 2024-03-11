%builtins range_check bitwise

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
// from starkware.cairo.common.math import unsigned_div_rem as felt_divmod
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.libs.utils import pow2alloc128
from src.libs.utils import felt_divmod

from src.libs.utils import (
    bitwise_divmod,
    // felt_divmod,
    felt_divmod_2pow32,
    word_reverse_endian_64,
    word_reverse_endian_16_RC,
    word_reverse_endian_24_RC,
    word_reverse_endian_32_RC,
    word_reverse_endian_40_RC,
    word_reverse_endian_48_RC,
    word_reverse_endian_56_RC,
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
            '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x0', '0x83d134b417a11286', '0x83c4e74783318c11', '0xda07e75684e80301', '0x478405030183d798', '0x2e316f6787687465', '0x756e696c85312e35', '0x23b95b80bcbca078', '0x459e0d4bc4949e27', '0x8946403c4e4bf8a6', '0xd345e360101baf02', '0x128f9ad9b0881ea7', '0x105ad9']
        homestead = [int(val, 16) for val in homestead]
        segments.write_arg(ids.values, homestead)

        decoded = [
            # parent
            "0x584bdb5d4e74fe97f5a5222b533fe132 2fd0b6ad3eb03f02c3221984e2c0b430",
            # uncle
            "0x1dcc4de8dec75d7aab85b567b6ccd41a d312451b948a7413f0a142fd40d49347",
            # coinbase
            "0x2a65aca4d5fc5b5c859090a6c34d164135398226",
            # state_root
            "0x066d4ac3bdc33c02918b289664d83d47 2de0cb4e6b2d84b3a4ab944a15d86f8b",
            # tx_root
            "0x99f4b5b22c1ed8d98815723f2c266fe8 d2971cf455a8c720810ec7fb1b4d9d7d",
            # receipts_root 
            "0x5cacb6059dd8035d38ab01c18aa04fd1 2ca983723a3232f4acbd8273f95b363d",
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

    let state_root = get_header_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(values, 3);

    %{
        print("state_root: ", hex(ids.state_root.low), hex(ids.state_root.high))
    %}

    let tx_root = get_header_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(values, 4);

    %{
        print("tx_root: ", hex(ids.tx_root.low), hex(ids.tx_root.high))
    %}

    let receipts_root = get_header_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }(values, 5);

    %{
        print("receipts_root: ", hex(ids.receipts_root.low), hex(ids.receipts_root.high))
    %}

    return ();
}

func get_header_field{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(rlp: felt*, field: felt) -> Uint256 {
    alloc_locals;
    
    //parent
    if(field == 0) {
        return get_32_bytes_value(rlp, 0, 4);
    }

    if(field == 1){
        return get_32_bytes_value(rlp, 4, 5);
    }

    // if(field == 2){
    //     return get_32_bytes_value(rlp, 8, 6);
    // }

    if(field == 3){
        return get_32_bytes_value(rlp, 11, 3);
    }

    if(field == 4){
        return get_32_bytes_value(rlp, 15, 4);
    }

    if(field == 5){
        return get_32_bytes_value(rlp, 19, 5);
    }

    return (Uint256(low=0, high=0));
}

func get_parent{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
} (rlp: felt*) -> Uint256 {
    // We have 4 bytes padding: 0xf9 0x02 0x18 0xa0 which can 
    let rlp_0 = rlp[0];
    let (rlp_0, thrash) = felt_divmod_2pow32(rlp_0);
    let rlp_1 = rlp[1];
    let rlp_2 = rlp[2];
    let (rlp_2_left, rlp_2_right) = felt_divmod_2pow32(rlp_2);
    let rlp_3 = rlp[3];
    let rlp_4 = rlp[4];
    let (thrash, rlp_4) = felt_divmod_2pow32(rlp_4);

    let res_low = rlp_2_right * 2 ** 96 + rlp_1 * 2 ** 32 + rlp_0;
    let res_high = rlp_4 * 2 ** 96 + rlp_3 * 2 ** 32 + rlp_2_left;

    return (Uint256(low=res_low, high=res_high));
}


func get_32_bytes_value{
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