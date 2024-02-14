%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize

from src.hdp.types import HeaderProof, MMRMeta, Account, AccountState, AccountSlot
from src.hdp.mmr import verify_mmr_meta
from src.hdp.header import verify_headers_inclusion
from src.hdp.account import init_accounts, verify_n_accounts, get_account_balance, get_account_nonce, get_account_state_root, get_account_code_hash, init_account_slots

from src.libs.utils import (
    pow2alloc127,
    write_felt_array_to_dict_keys
)

func main{
    output_ptr: felt*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    local results_root: Uint256;
    local tasks_root: Uint256;

    // Header Params
    local header_proofs_len: felt;
    let (header_proofs: HeaderProof*) = alloc();

    // MMR Params
    local mmr_meta: MMRMeta;

    // Account Params    
    let (accounts: Account*) = alloc();
    local accounts_len: felt;
    let (accounts_states: AccountState**) = alloc();
    let (account_slots: AccountSlot*) = alloc();
    local account_slots_len: felt;
    
    //Misc
    let pow2_array: felt* = pow2alloc127();
 
    %{

        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        def hex_to_int(x):
            return int(x, 16)

        def write_header_proofs(ptr, header_proofs):
            offset = 0
            ids.header_proofs_len = len(header_proofs)
            for header in header_proofs:
                memory[ptr._reference_value + offset] = header["leaf_idx"]
                memory[ptr._reference_value + offset + 1] = len(header["mmr_inclusion_proof"])
                memory[ptr._reference_value + offset + 2] = len(header["rlp_encoded_header"])
                memory[ptr._reference_value + offset + 3] = segments.gen_arg(hex_to_int_array(header["mmr_inclusion_proof"]))
                memory[ptr._reference_value + offset + 4] = segments.gen_arg(hex_to_int_array(header["rlp_encoded_header"]))
                offset += 5

        def write_mmr_meta(mmr_meta):
            ids.mmr_meta.id = mmr_meta["mmr_id"]
            ids.mmr_meta.root = hex_to_int(mmr_meta["mmr_root"])
            ids.mmr_meta.size = mmr_meta["mmr_size"]
            ids.mmr_meta.peaks_len = len(mmr_meta["mmr_peaks"])
            ids.mmr_meta.peaks = segments.gen_arg(hex_to_int_array(mmr_meta["mmr_peaks"]))

        ids.results_root.low = hex_to_int(program_input["results_root"]["low"])
        ids.results_root.high = hex_to_int(program_input["results_root"]["high"])
        ids.tasks_root.low = hex_to_int(program_input["tasks_root"]["low"])
        ids.tasks_root.high = hex_to_int(program_input["tasks_root"]["high"])
        
        # MMR Meta
        write_mmr_meta(program_input['header_batches'][0]['mmr_meta'])
        write_header_proofs(ids.header_proofs, program_input['header_batches'][0]["headers"])

        # Account Params
        ids.accounts_len = len(program_input['header_batches'][0]['accounts'])
        ids.account_slots_len = len(program_input['header_batches'][0]['account_slots'])
        # rest is written with init_accounts & init_account_slots func call



    %}
    
    // Check 1: Ensure we have a valid pair of mmr_root and peaks
    verify_mmr_meta{pow2_array=pow2_array}(mmr_meta);

    // Write the peaks to the dict if valid
    let (local peaks_dict) = default_dict_new(default_value=0);
    tempvar peaks_dict_start = peaks_dict;
    write_felt_array_to_dict_keys{dict_end=peaks_dict}(array=mmr_meta.peaks, index=mmr_meta.peaks_len - 1);

    // Check 2: Ensure the header is contained in a peak, and that the peak is known
    verify_headers_inclusion{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        peaks_dict=peaks_dict,
    }(
        header_proofs=header_proofs,
        header_proofs_len=header_proofs_len,
        mmr_size=mmr_meta.size
    );

    init_accounts(
        accounts=accounts,
        n_accounts=accounts_len,
        index=0
    );

    init_account_slots(
        account_slots=account_slots,
        n_account_slots=account_slots_len,
        index=0
    );

    // Check 3: Ensure the account proofs are valid
    verify_n_accounts{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        header_proofs=header_proofs,
    }(
        accounts=accounts,
        accounts_len=accounts_len,
        accounts_states=accounts_states,
        pow2_array=pow2_array,
    );

    // get_account_balance{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(
    //     rlp=accounts_states[0][0].values
    // );

    // get_account_nonce{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(
    //     rlp=accounts_states[0][0].values
    // );

    // get_account_state_root{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(
    //     rlp=accounts_states[0][0].values
    // );
    
    // get_account_code_hash{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array
    // }(
    //     rlp=accounts_states[0][0].values
    // );

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(peaks_dict_start, peaks_dict, 0);

    [ap] = mmr_meta.root;
    [ap] = [output_ptr], ap++;

    [ap] = results_root.low;
    [ap] = [output_ptr + 1], ap++;

    [ap] = results_root.high;
    [ap] = [output_ptr + 2], ap++;

    [ap] = tasks_root.high;
    [ap] = [output_ptr + 3], ap++;

    [ap] = tasks_root.low;
    [ap] = [output_ptr + 4], ap++;

    [ap] = output_ptr + 5, ap++;
    let output_ptr = output_ptr + 5;

    return();
}

//C3E94F3D6F233288
//32236F3D4FE9C322
//22C3E94F3D6F2332

// f84c808832236f3d4fe9c322a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470


// 0xa655cc1b171fe856
// 0x6ef8c092e64583ff

// 0xc0ad6c991be0485b
// 0x21b463e3b52f6201

// 0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421