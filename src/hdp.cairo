%builtins output pedersen range_check bitwise poseidon range_check96 add_mod mul_mod

from starkware.cairo.common.cairo_builtins import (
    BitwiseBuiltin,
    EcOpBuiltin,
    HashBuiltin,
    ModBuiltin,
    PoseidonBuiltin,
    SignatureBuiltin,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many, poseidon_hash
from starkware.cairo.common.cairo_keccak.keccak import (
    finalize_keccak,
    cairo_keccak_felts as keccak_felts,
)

from src.verifiers.verify import run_chain_state_verification
from src.verifiers.verify import run_injected_state_verification
from src.utils.merkle import compute_merkle_root
from src.types import MMRMeta
from src.utils.utils import mmr_metas_write_output_ptr, felt_array_to_uint256s, calculate_task_hash
from src.memorizers.evm.memorizer import EvmMemorizer
from src.memorizers.starknet.memorizer import StarknetMemorizer
from src.memorizers.bare import BareMemorizer
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder
from src.memorizers.starknet.state_access import StarknetStateAccess, StarknetDecoder
from src.utils.chain_info import Layout
from src.utils.merkle import compute_tasks_hash, compute_tasks_root, compute_results_root
from src.utils.chain_info import fetch_chain_info
from src.contract_bootloader.contract import compute_contract
from starkware.cairo.common.memcpy import memcpy
from src.memorizers.injected_state.memorizer import InjectedStateMemorizer, InjectedStateHashParams

from packages.eth_essentials.lib.utils import pow2alloc251, write_felt_array_to_dict_keys

func main{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    alloc_locals;
    let (keccak_ptr: felt*) = alloc();
    local keccak_ptr_start: felt* = keccak_ptr;

    run{
        output_ptr=output_ptr,
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        range_check96_ptr=range_check96_ptr,
        add_mod_ptr=add_mod_ptr,
        mul_mod_ptr=mul_mod_ptr,
    }();

    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr);
    return ();
}

func run{
    output_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: felt*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    alloc_locals;

    %{
        run_input = HDPInput.Schema().load(program_input)
        params = run_input.params
        compiled_class = run_input.compiled_class
        injected_state = run_input.injected_state
        chain_proofs = run_input.proofs_data.chain_proofs
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
    // TODO: @beeinger
    // let (unconstrined_memorizer, unconstrined_memorizer_start) = UnconstrinedStateMemorizer.init();

    %{
        if '__dict_manager' not in globals():
            __dict_manager = DictManager()
    %}

    let (injected_state_keys) = alloc();
    let (injected_state_values) = alloc();
    tempvar injected_state_len: felt = nondet %{ len(injected_states.entries()) %};
    %{
        segments.write_arg(ids.injected_state_keys, injected_states.keys())
        segments.write_arg(ids.injected_state_values, injected_states.values())
    %}
    with injected_state_memorizer {
        injected_state_load_loop(
            keys=injected_state_keys, values=injected_state_values, n=injected_state_len
        );
    }

    %{ injected_state_memorizer.set_key(poseidon_hash_many(LABEL_RUNTIME, key), value) for (key, value) in injected_states %}
    %{ syscall_handler = SyscallHandler(segments=segments, dict_manager=__dict_manager) %}

    // Misc
    let pow2_array: felt* = pow2alloc251();

    // MMR Params
    let (mmr_metas: MMRMeta*) = alloc();

    let (mmr_metas_len) = run_chain_state_verification{
        range_check_ptr=range_check_ptr,
        pedersen_ptr=pedersen_ptr,
        poseidon_ptr=poseidon_ptr,
        keccak_ptr=keccak_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        evm_memorizer=evm_memorizer,
        starknet_memorizer=starknet_memorizer,
        injected_state_memorizer=injected_state_memorizer,
        mmr_metas=mmr_metas,
    }();

    run_injected_state_verification{
        range_check_ptr=range_check_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        injected_state_memorizer=injected_state_memorizer,
    }();

    let evm_key_hasher_ptr = EvmStateAccess.init();
    let evm_decoder_ptr = EvmDecoder.init();
    let starknet_key_hasher_ptr = StarknetStateAccess.init();
    let starknet_decoder_ptr = StarknetDecoder.init();

    let (module_hash, retdata, retdata_size) = compute_contract{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        range_check96_ptr=range_check96_ptr,
        add_mod_ptr=add_mod_ptr,
        mul_mod_ptr=mul_mod_ptr,
        pow2_array=pow2_array,
        evm_memorizer=evm_memorizer,
        evm_decoder_ptr=evm_decoder_ptr,
        evm_key_hasher_ptr=evm_key_hasher_ptr,
        starknet_memorizer=starknet_memorizer,
        starknet_decoder_ptr=starknet_decoder_ptr,
        starknet_key_hasher_ptr=starknet_key_hasher_ptr,
        injected_state_memorizer=injected_state_memorizer,
    }(module_inputs, module_inputs_len);

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(evm_memorizer_start, evm_memorizer, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(
        starknet_memorizer_start, starknet_memorizer, BareMemorizer.DEFAULT_VALUE
    );
    default_dict_finalize(
        injected_state_memorizer_start, injected_state_memorizer, BareMemorizer.DEFAULT_VALUE
    );

    with keccak_ptr {
        let taskHash = calculate_task_hash(module_hash, public_inputs_len, public_inputs);
    }

    assert [output_ptr] = taskHash.low;
    assert [output_ptr + 1] = taskHash.high;
    let output_ptr = output_ptr + 2;

    let (local leafs: Uint256*) = alloc();
    felt_array_to_uint256s(counter=retdata_size, retdata=retdata, leafs=leafs);

    let output_root = compute_merkle_root(leafs, retdata_size);
    assert [output_ptr + 0] = output_root.low;
    assert [output_ptr + 1] = output_root.high;
    let output_ptr = output_ptr + 2;

    mmr_metas_write_output_ptr{output_ptr=output_ptr}(
        mmr_metas=mmr_metas, mmr_metas_len=mmr_metas_len
    );

    return ();
}

func injected_state_load_loop{
    poseidon_ptr: PoseidonBuiltin*, injected_state_memorizer: DictAccess*
}(keys: felt*, values: felt*, n: felt) {
    alloc_locals;

    if (n == 0) {
        return ();
    }

    let memorizer_key = InjectedStateHashParams.label{poseidon_ptr=poseidon_ptr}(label=keys[n - 1]);

    let (local data_ptr: felt*) = alloc();
    assert [data_ptr] = values[n - 1];

    InjectedStateMemorizer.add(key=memorizer_key, data=data_ptr);

    return injected_state_load_loop(keys=keys, values=values, n=n - 1);
}
