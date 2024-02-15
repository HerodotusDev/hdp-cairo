%builtins output range_check bitwise keccak poseidon

from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize

from src.hdp.types import Header, HeaderProof, MMRMeta, Account, AccountState, AccountSlot
from src.hdp.mmr import verify_mmr_meta
from src.hdp.header import verify_headers_inclusion
from src.hdp.account import populate_account_segments, verify_n_accounts, get_account_balance, get_account_nonce, get_account_state_root, get_account_code_hash
from src.hdp.slots import populate_account_slot_segments, verify_n_account_slots
from src.hdp.memorizer import initialize_memorizer
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
    local headers_len: felt;
    let (headers: Header*) = alloc();

    // MMR Params
    local mmr_meta: MMRMeta;

    // Account Params    
    let (accounts: Account*) = alloc();
    local accounts_len: felt;
    let (accounts_states: AccountState**) = alloc();
    let (account_slots: AccountSlot*) = alloc();
    let (account_slots_states: AccountState**) = alloc();
    local account_slots_len: felt;

    // Memorizer
    let (header_dict, header_dict_start) = initialize_memorizer();


    
    //Misc
    let pow2_array: felt* = pow2alloc127();
 
    %{
        def hex_to_int(x):
            return int(x, 16)

        def hex_to_int_array(hex_array):
            return [int(x, 16) for x in hex_array]

        def write_headers(ptr, headers):
            offset = 0
            ids.headers_len = len(headers)
            for header in headers:
                memory[ptr._reference_value + offset] = segments.gen_arg(hex_to_int_array(header["rlp_encoded_header"]))
                memory[ptr._reference_value + offset + 1] = len(header["rlp_encoded_header"])
                memory[ptr._reference_value + offset + 2] = header["bytes_len"]
                memory[ptr._reference_value + offset + 3] = header["leaf_idx"]
                memory[ptr._reference_value + offset + 4] = len(header["mmr_proof"])
                memory[ptr._reference_value + offset + 5] = segments.gen_arg(hex_to_int_array(header["mmr_proof"]))
                offset += 5
    
   %}
    // if these hints are one hint, the compiler goes on strike.
    %{
    
    
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
        write_headers(ids.headers, program_input['header_batches'][0]["headers"])
        # Account Params
        ids.accounts_len = len(program_input['header_batches'][0]['accounts'])
        ids.account_slots_len = len(program_input['header_batches'][0]['account_slots'])
        # rest is written with populate_account_segments & populate_account_slot_segments func call

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
        header_dict=header_dict,
    }(
        headers=headers,
        headers_len=headers_len,
        mmr_size=mmr_meta.size
    );

    populate_account_segments(
        accounts=accounts,
        n_accounts=accounts_len,
        index=0
    );

    populate_account_slot_segments(
        account_slots=account_slots,
        n_account_slots=account_slots_len,
        index=0
    );

    // Check 3: Ensure the account proofs are valid
    with header_dict {
        verify_n_accounts{
            range_check_ptr=range_check_ptr,
            bitwise_ptr=bitwise_ptr,
            keccak_ptr=keccak_ptr,
            headers=headers,
        }(
            accounts=accounts,
            accounts_len=accounts_len,
            accounts_states=accounts_states,
            pow2_array=pow2_array,
        );
    }

    // // Check 4: Ensure the account slot proofs are valid
    // verify_n_account_slots{
    //     range_check_ptr=range_check_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     keccak_ptr=keccak_ptr,
    //     accounts_states=accounts_states,
    // }(
    //     account_slots=account_slots,
    //     account_slots_len=account_slots_len,
    //     account_slots_states=account_slots_states,
    //     pow2_array=pow2_array,
    // );

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