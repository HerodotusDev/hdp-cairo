%builtins range_check bitwise keccak
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from src.hdp.decoders.header_decoder import HeaderDecoder
from src.libs.utils import pow2alloc128
from src.hdp.types import Transaction
from src.hdp.decoders.transaction_decoder import TransactionReader, TransactionSender
from src.hdp.verifiers.transaction_verifier import init_tx_stuct

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    local n_test_txs: felt;

    %{
        tx_array = [
            "0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51", # Type 0 (eip155)
            "0x2e923a6f09ba38f63ff9b722afd14b9e850432860b77df9011e92c1bf0eecf6b", # Type 0
            "0x423d6dfdeae9967847fb226e138ea5fad6279c12bf3343eae4d32c2477be3021", # Type 1
            "0x0d19225fe9ec3044d16008c3aceb0b9059cc22d66cd3ab847f6bd1e454342b4b", # Type 2
            "0x4b0070defa33cbc85f558323bf60132f600212cec3f4ab9e57260d40ff8949d9", # Type 3
        ]

        ids.n_test_txs = len(tx_array)
    %}

    test_tx_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        keccak_ptr=keccak_ptr,
    }(0);

    // %{ print("Testing Type 0") %}
    // test_type_0{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array,
    //     keccak_ptr=keccak_ptr
    // }();

    // %{ print("Testing Type 1") %}
    // test_type_1{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }();

    // %{ print("Testing Type 2") %}
    // test_type_2{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array,
    //     keccak_ptr=keccak_ptr
    // }();

    // %{ print("Testing Type 3") %}
    // test_type_3{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }();

    return ();
}

func test_tx_decoding{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
}(i: felt) {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len: felt;
    local bytes_len: felt;

    local expected_nonce: Uint256;
    local expected_gas_limit: Uint256;
    let (expected_receiver) = alloc();
    local expected_value: Uint256;
    let (expected_input) = alloc();
    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        from tests.python.test_tx_decoding import fetch_transaction_dict

        tx_dict = fetch_transaction_dict("0x237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51")

        print("tx_dict: ", tx_dict)

        # tx_bytes = bytes.fromhex("237f99e622d67413956b8674cf16ea56b0ba0a18a9f68a5e254f4ac8d2050b51")
        # ids.bytes_len = len(tx_bytes)
        # chunks = bytes_to_8_bytes_chunks_little(tx_bytes)
        # ids.rlp_len = len(chunks)
        # segments.write_arg(ids.rlp, chunks)

        # receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("b0ba0a18a9f68a5e254f4ac8d2050b51"))
        # segments.write_arg(ids.expected_receiver, receiver)

        # segments.write_arg(ids.expected_input, [0])

        # ids.expected_nonce.low = 0
        # ids.expected_nonce.high = 0

        # ids.expected_gas_limit.low = 0
        # ids.expected_gas_limit.high = 0

        # ids.expected_value.low = 0
        # ids.expected_value.high = 0

        # ids.expected_v.low = 0
        # ids.expected_v.high = 0

        # ids.expected_r.low = 0
        # ids.expected_r.high = 0

        # ids.expected_s.low = 0
        # ids.expected_s.high = 0
    %}

    return ();
}

func test_type_0{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;

    let (rlp) = alloc();
    local rlp_len: felt;
    local bytes_len: felt;

    local expected_nonce: Uint256;
    local expected_gas_price: Uint256;
    local expected_gas_limit: Uint256;
    let (expected_receiver) = alloc();
    local expected_value: Uint256;
    let (expected_input) = alloc();
    local expected_v: Uint256;
    local expected_r: Uint256;
    local expected_s: Uint256;

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

    let tx = Transaction(rlp=rlp, rlp_len=rlp_len, bytes_len=bytes_len, type=0);

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
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
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

    let tx = Transaction(rlp=rlp, rlp_len=rlp_len, bytes_len=bytes_len, type=1);

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
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
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

    let tx = Transaction(rlp=rlp, rlp_len=rlp_len, bytes_len=bytes_len, type=2);

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

    let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(
        tx, 10
    );
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
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, keccak_ptr: KeccakBuiltin*
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

        tx_bytes = bytes.fromhex("018309A0238405F5E1008522ECB25C008353EC6094C662C410C0ECF747543F5BA90660F6ABEBD9C8C480B903A4B72D42A100000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000001700D836A3E3BE7D1ABB2E2ED1CF011624DF098D43B38A14FB364BDAAEFE82B81103452AAB84F4B9A0458F2090038A966FB2267FA661928713F404031095B44170000000000000000000000000000000000000000000000000000000000009A02205412543965C1F5104E42933B54B3A080A0DA4366F6E73C05B7F267EA024FB8505BA2078240F1585F96424C2D1EE48211DA3B3F9177BF2B9880B4FC91D59E9A2000000000000000000000000000000000000000000000000000000000000000100000000000000003AC2371AF51D48ACD4084F9EC3F8FD121DC2787E592E8ED100000000000000008F902DE4D6F8A60F38F86E2E72D509A612FFBE1537B94D6907D2A065B1268D88E652C9281FDD317C6A778DB8E8989B7E10F089A9405B845B000000000000000000000000000000000C8F8620E3E9BD0D5287CBE661547C510000000000000000000000000000000041F3F74BEEDCB3A761886EA953F98B9E0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000A000000000000000000000000F6080D9FBEEBCD44D89AFFBFD42F098CBFF9281605CD48FCCBFD8AA2773FE22C217E808319FFCC1C5A6A463F7D8FA2DA482181960000000000000000000000000000000000000000000000000000000000190D5B01B64B1B3B690B43B9B514FB81377518F4039CD3E4F4914D8A6BDF01D679FB190000000000000000000000000000000000000000000000000000000000000005000000000000000000000000A0B86991C6218B36C1D19D4A2E9EB0CE3606EB4800000000000000000000000000D5FCD1548097845368B47DC3497599EAB811B9071E5405ACE1AFD64C682E65B08360B573C00370F4E3AD6E4F2CD800EC7D93D20000000000000000000000000000000000000000000000000000005D2180128000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ABE4BCB691385528AEF33D747702C592249BAF44BCD0C7BB67442248902EA8191CD8D270B579ADF17BC477592FEDD65100000000000000000000000000000000C08522ECB25C00E1A001C951A42B7275260E2D5826BE7D1297CD1628321389B4A35EAA2E6E682F331F01A0BABCA5339DCBA9C0AFFDFADFDF2152E9D51842B614B88B963281FE31C0B94BEAA0542BBA31AB00734A64DB3F8E219A1495BE55A925BED63E4384E6A35734FF6826")
        tx_bytes_len = len(tx_bytes)
        ids.bytes_len = tx_bytes_len
        chunks = bytes_to_8_bytes_chunks_little(tx_bytes)
        rlp_len = len(chunks)
        segments.write_arg(ids.rlp, chunks)
        ids.rlp_len = rlp_len

        receiver = bytes_to_8_bytes_chunks_little(bytes.fromhex("a8cb082a5a689e0d594d7da1e2d72a3d63adc1bd"))
        segments.write_arg(ids.expected_receiver, receiver)

        input_bytes = bytes.fromhex("b72d42a100000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000001700d836a3e3be7d1abb2e2ed1cf011624df098d43b38a14fb364bdaaefe82b81103452aab84f4b9a0458f2090038a966fb2267fa661928713f404031095b44170000000000000000000000000000000000000000000000000000000000009a02205412543965c1f5104e42933b54b3a080a0da4366f6e73c05b7f267ea024fb8505ba2078240f1585f96424c2d1ee48211da3b3f9177bf2b9880b4fc91d59e9a2000000000000000000000000000000000000000000000000000000000000000100000000000000003ac2371af51d48acd4084f9ec3f8fd121dc2787e592e8ed100000000000000008f902de4d6f8a60f38f86e2e72d509a612ffbe1537b94d6907d2a065b1268d88e652c9281fdd317c6a778db8e8989b7e10f089a9405b845b000000000000000000000000000000000c8f8620e3e9bd0d5287cbe661547c510000000000000000000000000000000041f3f74beedcb3a761886ea953f98b9e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000f6080d9fbeebcd44d89affbfd42f098cbff9281605cd48fccbfd8aa2773fe22c217e808319ffcc1c5a6a463f7d8fa2da482181960000000000000000000000000000000000000000000000000000000000190d5b01b64b1b3b690b43b9b514fb81377518f4039cd3e4f4914d8a6bdf01d679fb190000000000000000000000000000000000000000000000000000000000000005000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000d5fcd1548097845368b47dc3497599eab811b9071e5405ace1afd64c682e65b08360b573c00370f4e3ad6e4f2cd800ec7d93d20000000000000000000000000000000000000000000000000000005d2180128000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030abe4bcb691385528aef33d747702c592249baf44bcd0c7bb67442248902ea8191cd8d270b579adf17bc477592fedd65100000000000000000000000000000000")
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

    let tx = Transaction(rlp=rlp, rlp_len=rlp_len, bytes_len=bytes_len, type=3);

    // let nonce = TransactionReader.get_field_by_index(tx, 0);
    // assert expected_nonce.low = nonce.low;
    // assert expected_nonce.high = nonce.high;

    // // // N/A: Field 1

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

    // // Input:
    // eval_input(
    //     expected_input,
    //     expected_input_len,
    //     expected_input_bytes_len,
    //     tx,
    //     5
    // );
    // 03F9043D018309A0238405F5E1008522ECB25C008353EC6094C662C410C0ECF747543F5BA90660F6ABEBD9C8C480B903A4B72D42A100000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000340000000000000000000000000000000000000000000000000000000000000001700D836A3E3BE7D1ABB2E2ED1CF011624DF098D43B38A14FB364BDAAEFE82B81103452AAB84F4B9A0458F2090038A966FB2267FA661928713F404031095B44170000000000000000000000000000000000000000000000000000000000009A02205412543965C1F5104E42933B54B3A080A0DA4366F6E73C05B7F267EA024FB8505BA2078240F1585F96424C2D1EE48211DA3B3F9177BF2B9880B4FC91D59E9A2000000000000000000000000000000000000000000000000000000000000000100000000000000003AC2371AF51D48ACD4084F9EC3F8FD121DC2787E592E8ED100000000000000008F902DE4D6F8A60F38F86E2E72D509A612FFBE1537B94D6907D2A065B1268D88E652C9281FDD317C6A778DB8E8989B7E10F089A9405B845B000000000000000000000000000000000C8F8620E3E9BD0D5287CBE661547C510000000000000000000000000000000041F3F74BEEDCB3A761886EA953F98B9E0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000A000000000000000000000000F6080D9FBEEBCD44D89AFFBFD42F098CBFF9281605CD48FCCBFD8AA2773FE22C217E808319FFCC1C5A6A463F7D8FA2DA482181960000000000000000000000000000000000000000000000000000000000190D5B01B64B1B3B690B43B9B514FB81377518F4039CD3E4F4914D8A6BDF01D679FB190000000000000000000000000000000000000000000000000000000000000005000000000000000000000000A0B86991C6218B36C1D19D4A2E9EB0CE3606EB4800000000000000000000000000D5FCD1548097845368B47DC3497599EAB811B9071E5405ACE1AFD64C682E65B08360B573C00370F4E3AD6E4F2CD800EC7D93D20000000000000000000000000000000000000000000000000000005D2180128000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030ABE4BCB691385528AEF33D747702C592249BAF44BCD0C7BB67442248902EA8191CD8D270B579ADF17BC477592FEDD65100000000000000000000000000000000C08522ECB25C00E1A001C951A42B7275260E2D5826BE7D1297CD1628321389B4A35EAA2E6E682F331F01A0BABCA5339DCBA9C0AFFDFADFDF2152E9D51842B614B88B963281FE31C0B94BEAA0542BBA31AB00734A64DB3F8E219A1495BE55A925BED63E4384E6A35734FF6826

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
    // assert expected_chain_id.low = chain_id.low;
    // assert expected_chain_id.high = chain_id.high;

    // let (access_list, access_list_len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, 10);
    // assert expected_access_list[0] = access_list[0];
    // assert access_list_len = 1;
    // assert bytes_len = 1;

    // let max_fee = TransactionReader.get_field_by_index(tx, 11);
    // assert expected_max_fee.low = max_fee.low;
    // assert expected_max_fee.high = max_fee.high;

    // let max_prio_fee = TransactionReader.get_field_by_index(tx, 12);
    // assert expected_max_prio_fee.low = max_prio_fee.low;
    // assert expected_max_prio_fee.high = max_prio_fee.high;

    // let max_fee_per_blob_gas = TransactionReader.get_field_by_index(tx, 13);
    // assert expected_max_fee_per_blob_gas.low = max_fee_per_blob_gas.low;
    // assert expected_max_fee_per_blob_gas.high = max_fee_per_blob_gas.high;

    // // Blob hashes:
    // let (blob_versioned_hashes, blob_versioned_hashes_len, blob_versioned_hashes_bytes_len) = TransactionReader.get_felt_field_by_index(tx, 14);
    // assert expected_blob_versioned_hashes_len = blob_versioned_hashes_len;
    // assert expected_blob_versioned_hashes_bytes_len = blob_versioned_hashes_bytes_len;
    // assert expected_blob_versioned_hashes[0] = blob_versioned_hashes[0];
    // assert expected_blob_versioned_hashes[1] = blob_versioned_hashes[1];
    // assert expected_blob_versioned_hashes[2] = blob_versioned_hashes[2];
    // assert expected_blob_versioned_hashes[3] = blob_versioned_hashes[3];
    // assert expected_blob_versioned_hashes[4] = blob_versioned_hashes[4];

    let sender = TransactionSender.derive(tx);
    assert sender = 0x2C169DFe5fBbA12957Bdd0Ba47d9CEDbFE260CA7;

    return ();
}

func eval_input{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    expected_field: felt*,
    expected_len: felt,
    expected_bytes_len: felt,
    tx: Transaction,
    index: felt,
) {
    alloc_locals;

    let (field, len, bytes_len) = TransactionReader.get_felt_field_by_index(tx, index);

    %{
        i = 0
        while(i < ids.len):
            print(memory[ids.field + i] == input_chunks[i])

            i += 1
    %}

    // assert expected_len = len;
    // assert expected_bytes_len = bytes_len;

    // assert field[0] = expected_field[0];
    // assert field[1] = expected_field[1];
    // assert field[2] = expected_field[2];
    // assert field[3] = expected_field[3];
    // assert field[4] = expected_field[4];
    // assert field[5] = expected_field[5];
    // assert field[6] = expected_field[6];
    // assert field[7] = expected_field[7];
    // assert field[8] = expected_field[8];

    // assert field[9] = expected_field[9];
    // assert field[10] = expected_field[10];
    // assert field[11] = expected_field[11];
    // assert field[12] = expected_field[12];
    // assert field[13] = expected_field[13];
    // assert field[14] = expected_field[14];
    // assert field[15] = expected_field[15];

    // assert field[209] = expected_field[209];
    // assert field[210] = expected_field[210];
    // assert field[211] = expected_field[211];
    // assert field[212] = expected_field[212];

    return ();
}
