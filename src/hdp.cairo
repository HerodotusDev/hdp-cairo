%builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon

from starkware.cairo.common.cairo_builtins import (
    HashBuiltin,
    PoseidonBuiltin,
    BitwiseBuiltin,
    KeccakBuiltin,
    SignatureBuiltin,
    EcOpBuiltin,
)
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many, poseidon_hash

from src.verifiers.verify import run_state_verification
from src.module import init_module
from src.types import MMRMeta
from src.utils.utils import write_output_ptr
from src.memorizers.evm.memorizer import EvmMemorizer
from src.memorizers.starknet.memorizer import StarknetMemorizer
from src.memorizers.bare import BareMemorizer, SingleBareMemorizer
from src.memorizers.evm.state_access import EvmStateAccess, EvmDecoder
from src.memorizers.starknet.state_access import StarknetStateAccess, StarknetDecoder
from src.utils.chain_info import Layout
from src.utils.merkle import compute_tasks_hash, compute_tasks_root, compute_results_root
from src.utils.chain_info import fetch_chain_info
from src.contract_bootloader.contract import compute_contract

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
}() {
    alloc_locals;

    %{
        from tools.py.schema import HDPInput
        run_input = HDPInput.Schema().load(program_input)
        proofs = run_input.proofs
        params = run_input.params
        compiled_class = run_input.compiled_class
    %}

    // Memorizers
    let (evm_memorizer, evm_memorizer_start) = EvmMemorizer.init();
    let (starknet_memorizer, starknet_memorizer_start) = StarknetMemorizer.init();

    // Misc
    let pow2_array: felt* = pow2alloc251();

    // MMR Params
    let (mmr_metas: MMRMeta*) = alloc();

    let (local mmr_metas_len) = run_state_verification{
        range_check_ptr=range_check_ptr,
        poseidon_ptr=poseidon_ptr,
        keccak_ptr=keccak_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
        evm_memorizer=evm_memorizer,
        starknet_memorizer=starknet_memorizer,
        mmr_metas=mmr_metas,
    }();

    let evm_key_hasher_ptr = EvmStateAccess.init();
    let evm_decoder_ptr = EvmDecoder.init();
    let starknet_key_hasher_ptr = StarknetStateAccess.init();
    let starknet_decoder_ptr = StarknetDecoder.init();

    let (program_hash, results, results_len) = compute_tasks{
        pedersen_ptr=pedersen_ptr,
        range_check_ptr=range_check_ptr,
        ecdsa_ptr=ecdsa_ptr,
        bitwise_ptr=bitwise_ptr,
        ec_op_ptr=ec_op_ptr,
        keccak_ptr=keccak_ptr,
        poseidon_ptr=poseidon_ptr,
        pow2_array=pow2_array,
        evm_memorizer=evm_memorizer,
        evm_decoder_ptr=evm_decoder_ptr,
        evm_key_hasher_ptr=evm_key_hasher_ptr,
        starknet_memorizer=starknet_memorizer,
        starknet_decoder_ptr=starknet_decoder_ptr,
        starknet_key_hasher_ptr=starknet_key_hasher_ptr,
    }();

    // Post Verification Checks: Ensure dict consistency
    default_dict_finalize(evm_memorizer_start, evm_memorizer, BareMemorizer.DEFAULT_VALUE);
    default_dict_finalize(
        starknet_memorizer_start, starknet_memorizer, BareMemorizer.DEFAULT_VALUE
    );

    write_output_ptr{output_ptr=output_ptr}(
        mmr_metas=mmr_metas,
        mmr_metas_len=mmr_metas_len,
        tasks_root=tasks_root,
        results_root=results_root,
    );

    return ();
}

func compute_tasks{
    pedersen_ptr: HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    ec_op_ptr,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    pow2_array: felt*,
    evm_memorizer: DictAccess*,
    evm_decoder_ptr: felt***,
    evm_key_hasher_ptr: felt**,
    starknet_memorizer: DictAccess*,
    starknet_decoder_ptr: felt***,
    starknet_key_hasher_ptr: felt**,
}() -> (program_hash: felt, result: Uint256) {
    alloc_locals;

    let (result, program_hash) = compute_contract();

    %{ print(f"Task Result: {hex(ids.result.high * 2 ** 128 + ids.result.low)}") %}

    return (program_hash=program_hash, result=result);
}
