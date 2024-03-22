%builtins range_check bitwise keccak

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from src.libs.utils import pow2alloc128, write_felt_array_to_dict_keys
from src.libs.mpt import verify_mpt_content
from src.hdp.verifiers.transaction_verifier import verify_transaction


func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
}() {
    alloc_locals;
    local root: Uint256;
    local key: Uint256;
    let (proof: felt**) = alloc();
    let (proof_bytes_len: felt*) = alloc();
    local proof_len: felt;

    let pow2_array: felt* = pow2alloc128();

    %{
        debug_mode = True
        def conditional_print(*args):
            if debug_mode:
                print(*args)

        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        def nested_hex_to_int_array(hex_array):
            return [[int(x, 16) for x in y] for y in hex_array]
            

        chunks = [[13291948448274252281, 4275701062778911011, 320772149787112901, 14876612813271809712, 16999554366378453684, 11105135168380121667, 14213285491619273348, 909820000341004914, 5876529724380687819, 5414722406185874951, 4203894625473105825, 2634347041272214684, 11934592145502299326, 11953784011961335454, 3705889264659424622, 5434156475128151232, 11553531876657131452, 16692443537425245673, 12013077259027773214, 1150821109401955068, 6815225731988108100, 13898341387482228640, 8530570674761359230, 9281978318904097699, 13427075570015100720, 7537678082411700344, 7526987645890466779, 5805398439438701555, 3768372462617468266, 971496919557764130, 14171548105185024568, 2401956846934510951, 13923792020719898711, 15144479915922921884, 11923299206106587071, 14324401759889511594, 451149589684835247, 9259542123732973047, 2155905152], [6018624534924513784, 10525538546294394499, 8806133358683186908, 7749627341277165412, 6044039300597002309, 2393806290454631567, 16867793033417055436, 11611343181622757732, 9259542125106715480, 9259542123273814144, 8421504], [9259542123273835000, 12369108286088183936, 3013488726245701792, 2481125822421285853, 16348007963399537335, 3560132045420169375, 13293713350412004562, 3452280230648202575, 17378027235493076625, 10952724196943576734, 6422811565687277130, 6643187645769025955, 11904097152497350947, 16097729897279643009, 16510440240732374878, 6087998734470139854, 17711429870144455322, 6170077397066435141, 7184724862695823980, 5764414735017283713, 16509897460895857934, 11539557524070925660, 134769984816181555, 1250108175452729703, 4885521556503633380, 11009373862188878184, 8421504], [10234358700514018041, 1222301027591431899, 12461566130789391690, 9065270205153281990, 16128082546669678959, 13804662564240823269, 3555929438817646712, 6657571426578088848, 3740134735693965130, 5177145756971802870, 5776824366809369652, 10934926800396960337, 5953809634219965956, 11825081314345176354, 15983292340343109499, 2259637444074154650, 11578606118336063773, 3881319086668177376, 1118873440199071837, 2680048617412764671, 14512883531729702288, 17877142006542802848, 828122555277041982, 4637753765244871176, 168686880892681282, 7269847361822695453, 2471672331131766698, 1255512645822400252, 2341987958464478007, 12313635881119415307, 1591411434930775337, 5059486455237917779, 1364203320731011131, 44812540406401950, 12738400679075674223, 16113943201194157578, 13214221142733135376, 15659071570362149967, 2565292093590194174, 8112505917573760334, 6708213582643321476, 13487613222543304505, 14198415572172443508, 13987159675513351877, 10639436902857827904, 16041943015518577139, 10946677598813142313, 2481769468802347705, 16419179025849155492, 11551831539104923675, 15337604850530930367, 1203289583299643736, 17255015562947745398, 18229792784908269555, 10064071502326533792, 13187791148866870982, 15325682759507041932, 362108348591080044, 11100492914977251508, 249963455887813143, 4417240320628104839, 2072695678046179365, 6229870511013273014, 257982274714463734, 1154106881619048929, 12654381675375092034, 2158089377], [8284374219171592440, 9611264560761931009, 599685046825441039, 8934510980102096788, 4884847663665930398, 9665718464718345885, 9277555969884254194, 8944099760904322208, 2150963901488982310, 531270816253957356, 3718405162770834244, 8225410903711654023, 3630125831344342290, 178973038001148954, 5725984785731954563, 48750]]
        ids.root.low = 257761197311116532837196150678159856969
        ids.root.high = 159425385474712577316496950941176039553

        ids.key.low = 51841
        ids.key.high = 0

        ids.proof_len = len(chunks)

        proof_bytes_len = [308, 83, 211, 532, 122]
        segments.write_arg(ids.proof_bytes_len, proof_bytes_len)
        segments.write_arg(ids.proof, chunks)

    %}

    verify_transaction(
        proof=proof,
        proof_len=proof_len,
        bytes_len=proof_bytes_len,
        key_little=key,
        // n_nibbles_already_checked=0,
        // node_index=0,
        hash_to_assert=root,
        // pow2_array=pow2_array,
    );

    return ();
}

// namespace TransactionDecoder {



// }

// func verify_tx_mpt_proof{
//     range_check_ptr,
//     bitwise_ptr: BitwiseBuiltin*,
//     keccak_ptr: KeccakBuiltin*,
// }(
//     mpt_proof: felt**,
//     mpt_proof_bytes_len: felt*,
//     mpt_proof_len: felt,
//     key_little: Uint256,
//     n_nibbles_already_checked: felt,
//     node_index: felt,
//     hash_to_assert: Uint256,
//     pow2_array: felt*,
// ) {
//     alloc_locals;

//      let (value, value_len) = verify_mpt_proof{
//         range_check_ptr=range_check_ptr,
//         bitwise_ptr=bitwise_ptr,
//         keccak_ptr=keccak_ptr,
//     }(
//         mpt_proof=mpt_proof,
//         mpt_proof_bytes_len=mpt_proof_bytes_len,
//         mpt_proof_len=mpt_proof_len,
//         key_little=key_little,
//         n_nibbles_already_checked=n_nibbles_already_checked,
//         node_index=node_index,
//         hash_to_assert=hash_to_assert,
//         pow2_array=pow2_array,
//     );

//     %{ conditional_print("MPT Proof Valid! Start Decoding TX Values") %}

//     let value_node_index = mpt_proof_len - 1;

//     // The TX object will look like this: RLP([0x20/30, str(version | RLP([tx]))])
//     let (tx_string_prefix, tx_string_start_offset) = nibble_padding_unwrap{
//         range_check_ptr=range_check_ptr,
//         bitwise_ptr=bitwise_ptr,
//         pow2_array=pow2_array,
//     }(mpt_proof[value_node_index], mpt_proof_bytes_len[value_node_index]);

//     %{
//         print("TX string prefix:", hex(ids.tx_string_prefix))
//         print("TX string start offset:", ids.tx_string_start_offset)
//     %}

//     // ensure we receive an encoded string larger then 55 bytes. (sig alone is 65 bytes)
//     assert [range_check_ptr] = tx_string_prefix - 0xb7;
//     assert [range_check_ptr + 1] = 0xbf - tx_string_prefix;

//     let len_len = tx_string_prefix - 0xb7;
//     local version_byte_index = tx_string_start_offset + len_len + 1;
//     let version_byte = extract_byte_at_pos(mpt_proof[value_node_index][0], version_byte_index, pow2_array);
//     let range_check_ptr = range_check_ptr + 2;

//     let (res, res_len, bytes_len) = retrieve_from_rlp_list_via_idx{
//         range_check_ptr=range_check_ptr,
//         bitwise_ptr=bitwise_ptr,
//         pow2_array=pow2_array,
//     }(
//         rlp=mpt_proof[value_node_index],
//         value_idx=1,
//         item_starts_at_byte=version_byte_index + 3,
//         counter=0,
//     );

//     let val = res[0];

//     %{
    
//         print("TX RLP:", ids.val)
//     %}



//     return ();
// }