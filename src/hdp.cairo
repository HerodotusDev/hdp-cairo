%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon range_check96 add_mod mul_mod

from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    KeccakBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak_felts
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many, poseidon_hash

from src.verifiers.verify import run_chain_state_verification
from src.verifiers.verify import run_injected_state_verification
from src.utils.merkle import compute_merkle_root
from src.types import MMRMeta
from src.utils.utils import mmr_metas_write_output_ptr, felt_array_to_uint256s
from src.memorizers.evm.memorizer import EvmMemorizer
from src.memorizers.starknet.memorizer import StarknetMemorizer
from src.memorizers.bare import BareMemorizer, SingleBareMemorizer
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder
from src.memorizers.starknet.state_access import StarknetStateAccess, StarknetDecoder
from src.memorizers.injected_state.memorizer import InjectedStateMemorizer
from src.utils.chain_info import Layout
from src.utils.merkle import compute_tasks_hash, compute_tasks_root, compute_results_root
from src.utils.chain_info import fetch_chain_info
from src.contract_bootloader.contract import compute_contract
from starkware.cairo.common.memcpy import memcpy

from packages.eth_essentials.lib.utils import pow2alloc251, write_felt_array_to_dict_keys

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    run{
        output_ptr=output_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        ecdsa_ptr=ecdsa_ptr,
        bitwise_ptr=bitwise_ptr,
        ec_op_ptr=ec_op_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        range_check96_ptr=range_check96_ptr,
        add_mod_ptr=add_mod_ptr,
        mul_mod_ptr=mul_mod_ptr,
    }();

    return ();
}

func run{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    alloc_locals;

    %{
        run_input = HDPInput.Schema().load(program_input)
        chain_proofs = run_input.proofs_data.chain_proofs
        params = run_input.params
        compiled_class = run_input.compiled_class
        state_proofs = run_input.proofs_data.state_proofs
    %}

    let (public_inputs) = alloc();
    %{ segments.write_arg(ids.public_inputs, public_inputs) %}
    tempvar public_inputs_len: felt = nondet %{ len(public_inputs) %};

    let (private_inputs) = alloc();
    %{ segments.write_arg(ids.private_inputs, private_inputs) %}
    tempvar private_inputs_len: felt = nondet %{ len(private_inputs) %};

    let (module_inputs) = alloc();
    memcpy(dst=module_inputs, src=public_inputs, len=public_inputs_len);
    memcpy(dst=module_inputs + public_inputs_len, src=private_inputs, len=private_inputs_len);
    tempvar module_inputs_len: felt = public_inputs_len + private_inputs_len;

    // Memorizers
    let (evm_memorizer, evm_memorizer_start) = EvmMemorizer.init();
    let (starknet_memorizer, starknet_memorizer_start) = StarknetMemorizer.init();
    let (injected_state_memorizer, injected_state_memorizer_start) = InjectedStateMemorizer.init();

    // Misc
    let pow2_array: felt* = pow2alloc251();

    // MMR Params
    let (mmr_metas: MMRMeta*) = alloc();

    // let (mmr_metas_len) = run_chain_state_verification{
    //     range_check_ptr=range_check_ptr,
    //     pedersen_ptr=pedersen_ptr,
    //     poseidon_ptr=poseidon_ptr,
    //     keccak_ptr=keccak_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     pow2_array=pow2_array,
    //     evm_memorizer=evm_memorizer,
    //     starknet_memorizer=starknet_memorizer,
    //     injected_state_memorizer=injected_state_memorizer,
    //     mmr_metas=mmr_metas,
    // }();

    run_injected_state_verification{
        range_check_ptr=range_check_ptr,
        keccak_ptr=keccak_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        injected_state_memorizer=injected_state_memorizer,
    }();

    // let evm_key_hasher_ptr = EvmStateAccess.init();
    // let evm_decoder_ptr = EvmDecoder.init();
    // let starknet_key_hasher_ptr = StarknetStateAccess.init();
    // let starknet_decoder_ptr = StarknetDecoder.init();

    // let (module_hash, retdata, retdata_size) = compute_contract{
    //     pedersen_ptr=pedersen_ptr,
    //     range_check_ptr=range_check_ptr,
    //     ecdsa_ptr=ecdsa_ptr,
    //     bitwise_ptr=bitwise_ptr,
    //     ec_op_ptr=ec_op_ptr,
    //     keccak_ptr=keccak_ptr,
    //     poseidon_ptr=poseidon_ptr,
    //     range_check96_ptr=range_check96_ptr,
    //     add_mod_ptr=add_mod_ptr,
    //     mul_mod_ptr=mul_mod_ptr,
    //     pow2_array=pow2_array,
    //     evm_memorizer=evm_memorizer,
    //     evm_decoder_ptr=evm_decoder_ptr,
    //     evm_key_hasher_ptr=evm_key_hasher_ptr,
    //     starknet_memorizer=starknet_memorizer,
    //     starknet_decoder_ptr=starknet_decoder_ptr,
    //     starknet_key_hasher_ptr=starknet_key_hasher_ptr,
    //     injected_state_memorizer=injected_state_memorizer,
    // }(module_inputs, module_inputs_len);

    // // Post Verification Checks: Ensure dict consistency
    // default_dict_finalize(evm_memorizer_start, evm_memorizer, BareMemorizer.DEFAULT_VALUE);
    // default_dict_finalize(
    //     starknet_memorizer_start, starknet_memorizer, BareMemorizer.DEFAULT_VALUE
    // );
    // default_dict_finalize(
    //     injected_state_memorizer_start, injected_state_memorizer, BareMemorizer.DEFAULT_VALUE
    // );

    // let (task_hash_preimage) = alloc();
    // assert task_hash_preimage[0] = module_hash;
    // memcpy(dst=task_hash_preimage + 1, src=public_inputs, len=public_inputs_len);
    // tempvar task_hash_preimage_len: felt = 1 + public_inputs_len;

    // let (taskHash) = keccak_felts(task_hash_preimage_len, task_hash_preimage);

    // assert [output_ptr] = taskHash.low;
    // assert [output_ptr + 1] = taskHash.high;
    // let output_ptr = output_ptr + 2;

    // let (local leafs: Uint256*) = alloc();
    // felt_array_to_uint256s(counter=retdata_size, retdata=retdata, leafs=leafs);

    // let output_root = compute_merkle_root(leafs, retdata_size);
    // assert [output_ptr + 0] = output_root.low;
    // assert [output_ptr + 1] = output_root.high;
    // let output_ptr = output_ptr + 2;

    // mmr_metas_write_output_ptr{output_ptr=output_ptr}(
    //     mmr_metas=mmr_metas, mmr_metas_len=mmr_metas_len
    // );

    return ();
}
