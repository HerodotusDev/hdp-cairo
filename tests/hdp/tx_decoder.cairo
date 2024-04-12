%builtins range_check bitwise keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.hdp.decoders.header_decoder import HeaderDecoder
from src.libs.utils import pow2alloc128
from src.hdp.types import Transaction
from src.hdp.decoders.transaction_decoder import TransactionReader, TransactionSender

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    %{ print("Testing Type 0") %}
    test_type_0{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr
    }();

    %{ print("Testing Type 1") %}
    test_type_1{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }();

    %{ print("Testing Type 2") %}
    test_type_2{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr
    }();

    %{ print("Testing Type 3") %}
    test_type_3{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array
    }();


    return ();
}

func test_type_0{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len: felt;
    local bytes_len: felt;

    local expected_nonce: Uint256;
    local expected_gas_price: Uint256;
    local expected_gas_limit: Uint256;
    local expected_value: Uint256;

    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_receiver) = alloc();
    let (expected_input) = alloc();


    %{ 
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        tx_bytes = bytes.fromhex("0285051f4d5c0082520894e919522e686d4e998e0434488273c7fa2ce153d8648026a0e0e710bebe2e0e90b9a40aff9f2d60c2dda1511903d7c5b2873aa9cf47345fdaa07fd42387887731bc85783464e054b904434f10eacdbe6cc9c5dd052a6d3e2b26")
        ids.bytes_len = len(tx_bytes)
        rlp_chunks = bytes_to_8_bytes_chunks_little(tx_bytes)
        ids.rlp_len = len(rlp_chunks)
        # rlp_chunks = [0x8200743ba40b8516, 0xfa22661186940852, 0x4cf34eb4db07efd1, 0x87577e78b322a7bb, 0x8000981d2673be4c, 0xc02bf49a0325a025, 0xa35ee7669ac94a63, 0x979f24ea965dcd72, 0x319a8c181928ed60, 0xf38af11428a07646, 0x7c0d8a3cf0805a98, 0xa37f018c0bd9c632, 0x52845d9f93e8ab90, 0x36d84c]
        segments.write_arg(ids.rlp, rlp_chunks)

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("cff5c79a7d95a83b47a0fdc2d6a9c2a3f48bca29"))
        segments.write_arg(ids.expected_receiver, receiver)

        segments.write_arg(ids.expected_input, [0])

        ids.expected_nonce.low = 22
        ids.expected_nonce.high = 0

        ids.expected_gas_price.low = 50000000000
        ids.expected_gas_price.high = 0

        ids.expected_gas_limit.low = 21000
        ids.expected_gas_limit.high = 0

        ids.expected_value.low = 21601500000000000
        ids.expected_value.high = 0

        ids.expected_v.low = 37
        ids.expected_v.high = 0

        ids.expected_r.low = 0x5d96ea249f9760ed2819188c9a314676
        ids.expected_r.high = 0x25039af42bc0634ac99a66e75ea372cd

        ids.expected_s.low = 0x0b8c017fa390abe8939f5d84524cd836
        ids.expected_s.high = 0x2814f18af3985a80f03c8a0d7c32c6d9
    %}

    let tx = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=0
    );

    // let nonce = TransactionReader.get_field_by_index(tx, 0);
    // assert expected_nonce.low = nonce.low;
    // assert expected_nonce.high = nonce.high;

    // let gas_price = TransactionReader.get_field_by_index(tx, 1);
    // assert expected_gas_price.low = gas_price.low;
    // assert expected_gas_price.high = gas_price.high;

    // let gas_limit = TransactionReader.get_field_by_index(tx, 2);
    // assert expected_gas_limit.low = gas_limit.low;
    // assert expected_gas_limit.high = gas_limit.high;

    // let (receiver, _, _) = TransactionReader.get_felt_field_by_index(tx, 3);
    // assert expected_receiver[0] = receiver[0];
    // assert expected_receiver[1] = receiver[1];
    // assert expected_receiver[2] = receiver[2];

    // let value = TransactionReader.get_field_by_index(tx, 4);
    // assert expected_value.low = value.low;
    // assert expected_value.high = value.high;

    // let (input, input_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 5);
    // assert expected_input[0] = input[0];
    // assert input_len = 1;
    // assert bytes_len = 1;

    // let v = TransactionReader.get_field_by_index(tx, 6);

    // %{
    //     print("v.low: ", ids.v.low)
    
    // %}
    // assert expected_v.low = v.low;
    // assert expected_v.high = v.high;

    // let r = TransactionReader.get_field_by_index(tx, 7);
    // assert expected_r.low = r.low;
    // assert expected_r.high = r.high;

    // let s = TransactionReader.get_field_by_index(tx, 8);
    // assert expected_s.low = s.low;
    // assert expected_s.high = s.high;

    let sender = TransactionSender.derive(tx);
    assert sender = 0xcff5c79a7d95a83b47a0fdc2d6a9c2a3f48bca29;

    return ();
}

func test_type_1{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len: felt;
    local bytes_len: felt;

    local expected_nonce: Uint256;
    local expected_gas_price: Uint256;
    local expected_gas_limit: Uint256;
    local expected_value: Uint256;

    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_receiver) = alloc();
    let (expected_input) = alloc();
    let (expected_access_list) = alloc();

    %{ 
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        # https://etherscan.io/tx/0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021
        rlp_bytes = bytes.fromhex("018301160B850BC3FCAA9582523F94E25A329D385F77DF5D4ED56265BABE2B99A5436E8790323C93A997DD80C080A041AD1CE7F9902572C62D7154EAF81AC98E16FE5D0E93036DE72273474871EE85A003A70FBCE7C7BA9AE962820BD367AB7A83BA7689E6D5F61844F3172BB6419B9F")
        ids.bytes_len = len(rlp_bytes)
        chunks = bytes_to_8_bytes_chunks_little(rlp_bytes)
        ids.rlp_len = len(chunks)

        segments.write_arg(ids.rlp, chunks)

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("E25a329d385f77df5D4eD56265babe2b99A5436e"))
        segments.write_arg(ids.expected_receiver, receiver)

        segments.write_arg(ids.expected_input, [0])
        segments.write_arg(ids.expected_access_list, [0])

        ids.expected_nonce.low = 71179
        ids.expected_nonce.high = 0

        ids.expected_gas_price.low = 50532756117
        ids.expected_gas_price.high = 0

        ids.expected_gas_limit.low = 21055
        ids.expected_gas_limit.high = 0

        ids.expected_value.low = 40587632403126237
        ids.expected_value.high = 0

        ids.expected_v.low = 0
        ids.expected_v.high = 0

        ids.expected_r.low = 0x8e16fe5d0e93036de72273474871ee85
        ids.expected_r.high = 0x41ad1ce7f9902572c62d7154eaf81ac9

        ids.expected_s.low = 0x83ba7689e6d5f61844f3172bb6419b9f
        ids.expected_s.high = 0x03a70fbce7c7ba9ae962820bd367ab7a
    %}

    let tx = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=1
    );

    // let nonce = TransactionReader.get_field_by_index(tx, 0);
    // assert expected_nonce.low = nonce.low;
    // assert expected_nonce.high = nonce.high;

    // let gas_price = TransactionReader.get_field_by_index(tx, 1);
    // assert expected_gas_price.low = gas_price.low;
    // assert expected_gas_price.high = gas_price.high;

    // let gas_limit = TransactionReader.get_field_by_index(tx, 2);
    // assert expected_gas_limit.low = gas_limit.low;
    // assert expected_gas_limit.high = gas_limit.high;

    // let (receiver, _, _) = TransactionReader.get_felt_field_by_index(tx, 3);
    // assert expected_receiver[0] = receiver[0];
    // assert expected_receiver[1] = receiver[1];
    // assert expected_receiver[2] = receiver[2];

    // let value = TransactionReader.get_field_by_index(tx, 4);
    // assert expected_value.low = value.low;
    // assert expected_value.high = value.high;

    // let (input, input_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 5);
    // assert expected_input[0] = input[0];
    // assert input_len = 1;
    // assert bytes_len = 1;

    // let v = TransactionReader.get_field_by_index(tx, 6);
    // assert expected_v.low = v.low;
    // assert expected_v.high = v.high;

    // let r = TransactionReader.get_field_by_index(tx, 7);
    // assert expected_r.low = r.low;
    // assert expected_r.high = r.high;

    // let s = TransactionReader.get_field_by_index(tx, 8);
    // assert expected_s.low = s.low;
    // assert expected_s.high = s.high;

    // let chain_id = TransactionReader.get_field_by_index(tx, 9);
    // assert chain_id.low = 1;
    // assert chain_id.high = 0;

    // let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 10);
    // assert expected_access_list[0] = access_list[0];
    // assert access_list_len = 1;
    // assert bytes_len = 1;

    let sender = TransactionSender.derive(tx);
    assert sender = 0x2BCB6BC69991802124F04A1114EE487FF3FAD197;

    return ();
}

func test_type_2{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len = 15;
    local bytes_len = 114;

    local expected_chain_id: Uint256;
    local expected_nonce: Uint256;
    local expected_max_prio_fee: Uint256;
    local expected_max_fee: Uint256;
    local expected_gas_limit: Uint256;
    local expected_value: Uint256;

    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_receiver) = alloc();
    let (expected_input) = alloc();
    let (expected_access_list) = alloc();

    %{ 
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        rlp_chunks = [0x8562123202840501, 0x852825f7124d70f, 0x7bfdc2663ad00794, 0x43ca7711aeb4609e, 0x862387bb8478969d, 0x80c0800000c16ff2, 0x7c1fd3583c5bbca0, 0x1dd9c245a8f06926, 0x75f73fe1a5954ec, 0x339a6dcb69ef2344, 0x722687a3075ba087, 0x3260cc35db3fc512, 0x27bd707a26e541a, 0x4f76c8d336d82783, 0xbe6e]
        segments.write_arg(ids.rlp, rlp_chunks)

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("07d03A66c2fd7B9E60B4ae1177Ca439d967884bB"))
        segments.write_arg(ids.expected_receiver, receiver)

        segments.write_arg(ids.expected_input, [0])
        segments.write_arg(ids.expected_access_list, [0])

        ids.expected_chain_id.low = 1
        ids.expected_chain_id.high = 0

        ids.expected_nonce.low = 5
        ids.expected_nonce.high = 0

        ids.expected_max_prio_fee.low = 36835938
        ids.expected_max_prio_fee.high = 0

        ids.expected_max_fee.low = 68033999199
        ids.expected_max_fee.high = 0

        ids.expected_gas_limit.low = 21000
        ids.expected_gas_limit.high = 0

        ids.expected_value.low = 10000000000000000
        ids.expected_value.high = 0

        ids.expected_v.low = 0
        ids.expected_v.high = 0

        ids.expected_r.low = 0x54591afe735f074423ef69cb6d9a3387
        ids.expected_r.high = 0xbc5b3c58d31f7c2669f0a845c2d91dec

        ids.expected_s.low = 0x6ea207d77b028327d836d3c8764f6ebe
        ids.expected_s.high = 0x5b07a387267212c53fdb35cc60321a54
    %}

    let tx = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=2
    );

    let nonce = TransactionReader.get_field_by_index(tx, 0);
    assert expected_nonce.low = nonce.low;
    assert expected_nonce.high = nonce.high;

    // N/A: Field 1

    let gas_limit = TransactionReader.get_field_by_index(tx, 2);
    assert expected_gas_limit.low = gas_limit.low;
    assert expected_gas_limit.high = gas_limit.high;

    let (receiver, _, _) = TransactionReader.get_felt_field_by_index(tx, 3);
    assert expected_receiver[0] = receiver[0];
    assert expected_receiver[1] = receiver[1];
    assert expected_receiver[2] = receiver[2];

    let value = TransactionReader.get_field_by_index(tx, 4);
    assert expected_value.low = value.low;
    assert expected_value.high = value.high;

    let (input, input_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 5);
    assert expected_input[0] = input[0];
    assert input_len = 1;
    assert bytes_len = 1;

    let v = TransactionReader.get_field_by_index(tx, 6);
    assert expected_v.low = v.low;
    assert expected_v.high = v.high;

    let r = TransactionReader.get_field_by_index(tx, 7);
    assert expected_r.low = r.low;
    assert expected_r.high = r.high;

    let s = TransactionReader.get_field_by_index(tx, 8);
    assert expected_s.low = s.low;
    assert expected_s.high = s.high;

    let chain_id = TransactionReader.get_field_by_index(tx, 9);
    assert expected_chain_id.low = chain_id.low;
    assert expected_chain_id.high = chain_id.high;

    let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 10);
    assert expected_access_list[0] = access_list[0];
    assert access_list_len = 1;
    assert bytes_len = 1;

    let max_fee = TransactionReader.get_field_by_index(tx, 11);
    assert expected_max_fee.low = max_fee.low;
    assert expected_max_fee.high = max_fee.high;

    let max_prio_fee = TransactionReader.get_field_by_index(tx, 12);
    assert expected_max_prio_fee.low = max_prio_fee.low;
    assert expected_max_prio_fee.high = max_prio_fee.high;

    let sender = TransactionSender.derive(tx);
    assert sender = 0x7cd6bf329dbd94f699d204ed83f65d5d6b8a9e8c;
    return ();
}

func test_type_3{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len: felt;
    local bytes_len: felt;

    local expected_chain_id: Uint256;
    local expected_nonce: Uint256;
    local expected_max_prio_fee: Uint256;
    local expected_max_fee: Uint256;
    local expected_gas_limit: Uint256;
    local expected_value: Uint256;

    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    let (expected_receiver) = alloc();

    let (expected_input) = alloc();
    local expected_input_len: felt;
    local expected_input_bytes_len: felt;

    let (expected_access_list) = alloc();

    let (expected_blob_versioned_hashes) = alloc();
    local expected_blob_versioned_hashes_len: felt;
    local expected_blob_versioned_hashes_bytes_len: felt;

    local expected_max_fee_per_blob_gas: Uint256;

    %{ 
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        tx_bytes = bytes.fromhex("018213CF85012A05F20085067BF3114E837A120094A8CB082A5A689E0D594D7DA1E2D72A3D63ADC1BD80B906A4701F58C50000000000000000000000000000000000000000000000000000000000071735856067108BA30E184D777A3FC833F37983F2E48C57A597785755811D2A027B220000000000000000000000000000000000000000000000000000000010B9BDD9000000000000000000000000000000000000000000000000000000000000000365EA057C6834D687253AF6DD58745C268070507CF1F701ED510B4092EAF93601805CA1E763747779C17F34899ACD3507BB5BA2E22DC2C4CD862EF27E1A1462610000000000000000000000000000000000000000000000000000000065F7F03A66B6785A423D7803BE31774427AA91DB5973E0534F28D1C2FED8A53B34231DC100000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000717360000000000000000000000000000000000000000000000000000000065F7F08A0000000000000000000000000000000000000000000000000000000010B9C1C182C0740D3A41268DE6B52AC1EAEE241298824DB68122F8787CB7A5E732435259000000000000000000000000000000000000000000000000000000000000000452A2EB0E93CE6A696BBD597709A2C1DFD5D5C9318F9E9F08087A88712E4606C5FCA6BEE4022BD331455BD97FC8B1006091FABFF53A1F01F9E22EAC597641F4864AF974C95B6D000E82565B427812526EAACC1C69DBC24606EA0E691F4C477D3300000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000480000000000000000000000000000000000000000000000000000000000000031800000000000000000000000000000000000000000000800B0000000000000000000000000000000000000000000000000000000000000004856067108BA30E184D777A3FC833F37983F2E48C57A597785755811D2A027B2200000580000000000000000000000000000000000000800B000000000000000000000000000000000000000000000000000000000000000300000000000000000000000065F7F08A00000000000000000000000065F7F0D2000105800000000000000000000000000000000000008001000000000000000000000000000000000000000000000000000000000000000552A2EB0E93CE6A696BBD597709A2C1DFD5D5C9318F9E9F08087A88712E4606C50001058000000000000000000000000000000000000080010000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000400010580000000000000000000000000000000000000801100000000000000000000000000000000000000000000000000000000000000072B15A2246FE5C72065054CEB2B0E3EC0E0E8CC7C70C3651D54FB314F8563E72F000105800000000000000000000000000000000000008011000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000001058000000000000000000000000000000000000080080000000000000000000000000000000000000000000000000000000000000000792A32F10DB9C017A5D17EF7D3D2AAC295A76115C4F71AFC2670A95B96C906700001058000000000000000000000000000000000000080080000000000000000000000000000000000000000000000000000000000000001826C71922C8C0347C4CC9534E07489C1ABF737C329184DE5597F8D657AEC337C00010580000000000000000000000000000000000000800800000000000000000000000000000000000000000000000000000000000000029BACB83454043EBDCB629D77075CCFB129F154B44283B83FB1E6A3AB5430F25E0000000000000000000000000000000000000000000000000000000000000000000000000000009101398AB6798047B0214B7C3E3983DC26FF2EEC3316ED34BC31A4823453ED02EF9B37CA6A2AFDB55E9F07A563E263FEDF3CA3AA7DAA49CC7772C351F2925037D6F775A14F7704F2107748CC766AB5D777541584DBF70A49DE223170822E452DA6FB83A3EA567570639B3791B2496C7F0CBE620B664CD9C38487DE263F37394E93AC83103C0E5DB6702246A14E527F854F87000000000000000000000000000000C001E1A0015560DE5B6C2EDA4B74CFD91620C300829C9C15D290A68BF43B10FE91C365F980A030D1D9B80835D7E5368DD74549EE3CD47948DA17B07E4F98F42702726ADD470BA027EDA9A5B312C0EF4E7C3C1C48716642B20553ECEE0478B1F128E99CF5612095")
        tx_bytes_len = len(tx_bytes)
        rlp_chunks = bytes_to_8_bytes_chunks_little(tx_bytes)
        rlp_len = len(rlp_chunks)
        segments.write_arg(ids.rlp, rlp_chunks)
        ids.rlp_len = rlp_len
        ids.bytes_len = tx_bytes_len

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("a8cb082a5a689e0d594d7da1e2d72a3d63adc1bd"))
        segments.write_arg(ids.expected_receiver, receiver)

        input_bytes = bytes.fromhex("701f58c50000000000000000000000000000000000000000000000000000000000071735856067108ba30e184d777a3fc833f37983f2e48c57a597785755811d2a027b220000000000000000000000000000000000000000000000000000000010b9bdd9000000000000000000000000000000000000000000000000000000000000000365ea057c6834d687253af6dd58745c268070507cf1f701ed510b4092eaf93601805ca1e763747779c17f34899acd3507bb5ba2e22dc2c4cd862ef27e1a1462610000000000000000000000000000000000000000000000000000000065f7f03a66b6785a423d7803be31774427aa91db5973e0534f28d1c2fed8a53b34231dc100000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000717360000000000000000000000000000000000000000000000000000000065f7f08a0000000000000000000000000000000000000000000000000000000010b9c1c182c0740d3a41268de6b52ac1eaee241298824db68122f8787cb7a5e732435259000000000000000000000000000000000000000000000000000000000000000452a2eb0e93ce6a696bbd597709a2c1dfd5d5c9318f9e9f08087a88712e4606c5fca6bee4022bd331455bd97fc8b1006091fabff53a1f01f9e22eac597641f4864af974c95b6d000e82565b427812526eaacc1c69dbc24606ea0e691f4c477d3300000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000480000000000000000000000000000000000000000000000000000000000000031800000000000000000000000000000000000000000000800b0000000000000000000000000000000000000000000000000000000000000004856067108ba30e184d777a3fc833f37983f2e48c57a597785755811d2a027b2200000580000000000000000000000000000000000000800b000000000000000000000000000000000000000000000000000000000000000300000000000000000000000065f7f08a00000000000000000000000065f7f0d2000105800000000000000000000000000000000000008001000000000000000000000000000000000000000000000000000000000000000552a2eb0e93ce6a696bbd597709a2c1dfd5d5c9318f9e9f08087a88712e4606c50001058000000000000000000000000000000000000080010000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000400010580000000000000000000000000000000000000801100000000000000000000000000000000000000000000000000000000000000072b15a2246fe5c72065054ceb2b0e3ec0e0e8cc7c70c3651d54fb314f8563e72f000105800000000000000000000000000000000000008011000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000001058000000000000000000000000000000000000080080000000000000000000000000000000000000000000000000000000000000000792a32f10db9c017a5d17ef7d3d2aac295a76115c4f71afc2670a95b96c906700001058000000000000000000000000000000000000080080000000000000000000000000000000000000000000000000000000000000001826c71922c8c0347c4cc9534e07489c1abf737c329184de5597f8d657aec337c00010580000000000000000000000000000000000000800800000000000000000000000000000000000000000000000000000000000000029bacb83454043ebdcb629d77075ccfb129f154b44283b83fb1e6a3ab5430f25e0000000000000000000000000000000000000000000000000000000000000000000000000000009101398ab6798047b0214b7c3e3983dc26ff2eec3316ed34bc31a4823453ed02ef9b37ca6a2afdb55e9f07a563e263fedf3ca3aa7daa49cc7772c351f2925037d6f775a14f7704f2107748cc766ab5d777541584dbf70a49de223170822e452da6fb83a3ea567570639b3791b2496c7f0cbe620b664cd9c38487de263f37394e93ac83103c0e5db6702246a14e527f854f87000000000000000000000000000000")
        ids.expected_input_bytes_len = len(input_bytes)
        input_chunks = bytes_to_8_bytes_chunks_little(input_bytes)

        ids.expected_input_len = len(input_chunks)
        segments.write_arg(ids.expected_input, input_chunks)
        
        blob_hashes_bytes = bytes.fromhex("a0015560de5b6c2eda4b74cfd91620c300829c9c15d290a68bf43b10fe91c365f9")
        ids.expected_blob_versioned_hashes_bytes_len = len(blob_hashes_bytes)
        blob_hashes_chunks = bytes_to_8_bytes_chunks_little(blob_hashes_bytes)
        ids.expected_blob_versioned_hashes_len = len(blob_hashes_chunks)
        segments.write_arg(ids.expected_blob_versioned_hashes, blob_hashes_chunks)

        segments.write_arg(ids.expected_access_list, [0])

        ids.expected_chain_id.low = 1
        ids.expected_chain_id.high = 0

        ids.expected_nonce.low = 5071
        ids.expected_nonce.high = 0

        ids.expected_max_prio_fee.low = 5000000000
        ids.expected_max_prio_fee.high = 0

        ids.expected_max_fee.low = 27849331022
        ids.expected_max_fee.high = 0

        ids.expected_gas_limit.low = 8000000
        ids.expected_gas_limit.high = 0

        ids.expected_value.low = 0
        ids.expected_value.high = 0

        ids.expected_max_fee_per_blob_gas.low = 1
        ids.expected_max_fee_per_blob_gas.high = 0

        ids.expected_v.low = 0
        ids.expected_v.high = 0

        ids.expected_r.low = 0x7948da17b07e4f98f42702726add470b
        ids.expected_r.high = 0x30d1d9b80835d7e5368dd74549ee3cd4

        ids.expected_s.low = 0xb20553ecee0478b1f128e99cf5612095
        ids.expected_s.high = 0x27eda9a5b312c0ef4e7c3c1c48716642


    %}

    let tx = Transaction(
        rlp=rlp,
        rlp_len=rlp_len,
        bytes_len=bytes_len,
        type=3
    );

    let nonce = TransactionReader.get_field_by_index(tx, 0);
    assert expected_nonce.low = nonce.low;
    assert expected_nonce.high = nonce.high;

    // // N/A: Field 1

    let gas_limit = TransactionReader.get_field_by_index(tx, 2);
    assert expected_gas_limit.low = gas_limit.low;
    assert expected_gas_limit.high = gas_limit.high;

    let (receiver, _, _) = TransactionReader.get_felt_field_by_index(tx, 3);
    assert expected_receiver[0] = receiver[0];
    assert expected_receiver[1] = receiver[1];
    assert expected_receiver[2] = receiver[2];

    let value = TransactionReader.get_field_by_index(tx, 4);
    assert expected_value.low = value.low;
    assert expected_value.high = value.high;

    // Input:
    eval_input(
        expected_input,
        expected_input_len,
        expected_input_bytes_len,
        tx,
        5
    );


    let v = TransactionReader.get_field_by_index(tx, 6);
    assert expected_v.low = v.low;
    assert expected_v.high = v.high;

    let r = TransactionReader.get_field_by_index(tx, 7);
    assert expected_r.low = r.low;
    assert expected_r.high = r.high;

    let s = TransactionReader.get_field_by_index(tx, 8);
    assert expected_s.low = s.low;
    assert expected_s.high = s.high;

    let chain_id = TransactionReader.get_field_by_index(tx, 9);
    assert expected_chain_id.low = chain_id.low;
    assert expected_chain_id.high = chain_id.high;

    let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 10);
    assert expected_access_list[0] = access_list[0];
    assert access_list_len = 1;
    assert bytes_len = 1;

    let max_fee = TransactionReader.get_field_by_index(tx, 11);
    assert expected_max_fee.low = max_fee.low;
    assert expected_max_fee.high = max_fee.high;

    let max_prio_fee = TransactionReader.get_field_by_index(tx, 12);
    assert expected_max_prio_fee.low = max_prio_fee.low;
    assert expected_max_prio_fee.high = max_prio_fee.high;

    let max_fee_per_blob_gas = TransactionReader.get_field_by_index(tx, 13);
    assert expected_max_fee_per_blob_gas.low = max_fee_per_blob_gas.low;
    assert expected_max_fee_per_blob_gas.high = max_fee_per_blob_gas.high;

    // Blob hashes:
    let (blob_versioned_hashes, blob_versioned_hashes_len, blob_versioned_hashes_bytes_len) = TransactionReader.get_felt_field_by_index(tx, 14);
    assert expected_blob_versioned_hashes_len = blob_versioned_hashes_len;
    assert expected_blob_versioned_hashes_bytes_len = blob_versioned_hashes_bytes_len;
    assert expected_blob_versioned_hashes[0] = blob_versioned_hashes[0];
    assert expected_blob_versioned_hashes[1] = blob_versioned_hashes[1];
    assert expected_blob_versioned_hashes[2] = blob_versioned_hashes[2];
    assert expected_blob_versioned_hashes[3] = blob_versioned_hashes[3];
    assert expected_blob_versioned_hashes[4] = blob_versioned_hashes[4];

    let sender = TransactionSender.derive(tx);
    assert sender = 0x2BCB6BC69991802124F04A1114EE487FF3FAD197;


    return ();
}

func eval_input{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*
}(expected_field: felt*, expected_len: felt, expected_bytes_len: felt, tx: Transaction, index: felt) {
    alloc_locals;

    let (field, len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, index);
    
    assert expected_len = len;
    assert expected_bytes_len = bytes_len;

    assert field[0] = expected_field[0];
    assert field[1] = expected_field[1];
    assert field[2] = expected_field[2];
    assert field[3] = expected_field[3];
    assert field[4] = expected_field[4];
    assert field[5] = expected_field[5];
    assert field[6] = expected_field[6];
    assert field[7] = expected_field[7];
    assert field[8] = expected_field[8];

    assert field[9] = expected_field[9];
    assert field[10] = expected_field[10];
    assert field[11] = expected_field[11];
    assert field[12] = expected_field[12];
    assert field[13] = expected_field[13];
    assert field[14] = expected_field[14];
    assert field[15] = expected_field[15];

    assert field[209] = expected_field[209];
    assert field[210] = expected_field[210];
    assert field[211] = expected_field[211];
    assert field[212] = expected_field[212];

    return ();
}
