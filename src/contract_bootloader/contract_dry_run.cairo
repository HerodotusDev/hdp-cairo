// %builtins output pedersen range_check ecdsa bitwise ec_op keccak poseidon

// from starkware.cairo.common.cairo_builtins import (
//     HashBuiltin,
//     PoseidonBuiltin,
//     BitwiseBuiltin,
//     KeccakBuiltin,
//     SignatureBuiltin,
//     EcOpBuiltin,
// )
// from starkware.cairo.common.alloc import alloc
// from starkware.cairo.common.uint256 import Uint256
// from starkware.cairo.common.dict_access import DictAccess
// from starkware.cairo.common.default_dict import default_dict_new, default_dict_finalize
// from starkware.cairo.common.builtin_keccak.keccak import keccak, keccak_bigend
// from src.contract_bootloader.contract_class.compiled_class import CompiledClass, compiled_class_hash
// from src.contract_bootloader.contract_bootloader import (
//     run_contract_bootloader,
//     compute_program_hash,
// )
// from starkware.cairo.common.memcpy import memcpy

// struct DryRunOutput {
//     program_hash: felt,
//     result: Uint256,
// }


// func main{
//     output_ptr: felt*,
//     pedersen_ptr: HashBuiltin*,
//     range_check_ptr,
//     ecdsa_ptr,
//     bitwise_ptr: BitwiseBuiltin*,
//     ec_op_ptr,
//     keccak_ptr: KeccakBuiltin*,
//     poseidon_ptr: PoseidonBuiltin*,
// }() {
//     alloc_locals;

//     %{
//         dry_run_input = HDPDryRunInput.Schema().load(program_input)
//         params = dry_run_input.params
//         compiled_class = dry_run_input.compiled_class
//     %}

//     local params_len: felt;
//     let (params) = alloc();
//     local compiled_class: CompiledClass*;

//     %{ ids.compiled_class = segments.gen_arg(get_compiled_class_struct(compiled_class=compiled_class)) %}

//     %{
//         ids.params_len = len(params)
//         segments.write_arg(ids.params, [param.value for param in params])
//     %}

//     let (builtin_costs: felt*) = alloc();
//     assert builtin_costs[0] = 0;
//     assert builtin_costs[1] = 0;
//     assert builtin_costs[2] = 0;
//     assert builtin_costs[3] = 0;
//     assert builtin_costs[4] = 0;

//     assert compiled_class.bytecode_ptr[compiled_class.bytecode_length] = 0x208b7fff7fff7ffe;
//     assert compiled_class.bytecode_ptr[compiled_class.bytecode_length + 1] = cast(
//         builtin_costs, felt
//     );

//     let (local program_hash) = compiled_class_hash(compiled_class=compiled_class);

//     %{ print("program_hash", hex(ids.program_hash)) %}

//     %{
//         vm_load_program(
//             compiled_class.get_runnable_program(entrypoint_builtins=[]),
//             ids.compiled_class.bytecode_ptr
//         )
//     %}

//     let (local evm_memorizer) = default_dict_new(default_value=7);
//     let (local starknet_memorizer) = default_dict_new(default_value=7);
//     tempvar pow2_array: felt* = nondet %{ segments.add() %};

//     %{
//         if '__dict_manager' not in globals():
//             __dict_manager = DictManager()
//     %}

//     %{ syscall_handler = DryRunSyscallHandler(segments=segments, dict_manager=__dict_manager) %}

//     tempvar calldata: felt* = nondet %{ segments.add() %};

//     assert calldata[0] = nondet %{ ids.evm_memorizer.address_.segment_index %};
//     assert calldata[1] = nondet %{ ids.evm_memorizer.address_.offset %};
//     assert calldata[2] = nondet %{ ids.starknet_memorizer.address_.segment_index %};
//     assert calldata[3] = nondet %{ ids.starknet_memorizer.address_.offset %};

//     memcpy(dst=calldata + 4, src=params, len=params_len);
//     let calldata_size = 4 + params_len;

//     let (evm_decoder_ptr: felt***) = alloc();
//     let (starknet_decoder_ptr: felt***) = alloc();
//     let (evm_key_hasher_ptr: felt**) = alloc();
//     let (starknet_key_hasher_ptr: felt**) = alloc();

//     with evm_memorizer, starknet_memorizer, pow2_array, evm_decoder_ptr, starknet_decoder_ptr, evm_key_hasher_ptr, starknet_key_hasher_ptr {
//         let (retdata_size, retdata) = run_contract_bootloader(
//             compiled_class=compiled_class, calldata_size=calldata_size, calldata=calldata, dry_run=1
//         );
//     }

//     tempvar low;
//     tempvar high;

//     if (retdata_size == 0) {
//         low = 0x0;
//         high = 0x0;
//     }
//     if (retdata_size == 1) {
//         low = retdata[0];
//         high = 0x0;
//     }
//     if (retdata_size == 2) {
//         low = retdata[0];
//         high = retdata[1];
//     }


//     local result: Uint256 = Uint256(low=low, high=high);

//     %{ print(f"Task Result: {hex(ids.result.high * 2 ** 128 + ids.result.low)}") %}

//     // Write DryRunOutput to output.
//     assert [cast(output_ptr, DryRunOutput*)] = DryRunOutput(
//         program_hash=program_hash, result=result
//     );
//     let output_ptr = output_ptr + DryRunOutput.SIZE;

//     return ();
// }

%builtins output range_check bitwise poseidon range_check96 add_mod mul_mod
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, ModBuiltin, BitwiseBuiltin
from starkware.cairo.common.registers import get_label_location


from src.utils.debug import print_felt, print_uint384, print_string
from ec_ops import is_on_curve_g1, derive_g1_point_from_x
from definitions import UInt384, G1Point
from packages.eth_essentials.lib.utils import (
    felt_divmod,
)


// from packages.eth_essentials.lib.utils import pow2alloc251, write_felt_array_to_dict_keys


func main{
    output_ptr,
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
}() {
    alloc_locals;

    let pow2_array: felt* = pow2alloc251();
    


    // print_felt(1);
    // let p = G1Point(
    //     x=UInt384(
    //         77209383603911340680728987323,
    //         49921657856232494206459177023,
    //         24654436777218005952848247045,
    //         7410505851925769877053596556,
    //     ),
    //     y=UInt384(
    //         4578755106311036904654095050,
    //         31671107278004379566943975610,
    //         64119167930385062737200089033,
    //         5354471328347505754258634440,
    //     ),
    // );
    // let (res) = is_on_curve_g1(1, p);

    


    let x = UInt384(
        d0=0x43a4349c2f833e23209eec32,
        d1=0x0884b9a3aa10bb098e084ca1,
        d2=0x8759162520009d30bce6d5ca,
        d3=0x86c6e5c9d071c9b6dde93804
    );




// 0x86c6e5c9d071c9b6dde93804 8759162520009d30bce6d5ca 0884b9a3aa10bb098e084ca1 43a4349c2f833e23209eec32
    // print_uint384(x);

    with pow2_array {
        compute_committee_hash(x);
    }
    
    return ();
}


// Compute the hash of the committee point h(x||y)
func compute_committee_hash{
    range_check_ptr,
    range_check96_ptr: felt*,
    add_mod_ptr: ModBuiltin*,
    mul_mod_ptr: ModBuiltin*,
    pow2_array: felt*,
}(compressed_g1: UInt384) {
    alloc_locals;

    // Decompress G1 point and perform sanity checks
    let (flags, x_point) = decompress_g1(compressed_g1);
    // assert flags.compression_bit = 1;
    // assert flags.infinity_bit = 0;

    // print_string('Decompressed');

    // Derive the full G1 point and hash it
    let (point) = derive_g1_point_from_x(curve_id=1, x=x_point, s=flags.sign_bit);
    print_string('Decompressed Point:');
    print_uint384(point.x);
    print_uint384(point.y);
    return ();


}



// Structure to hold flags for compressed G1 points
struct CompressedG1Flags {
    compression_bit: felt,  // Bit 383
    infinity_bit: felt,  // Bit 382
    sign_bit: felt,  // Bit 381
}

// Decompress a G1 point from its compressed form
func decompress_g1{range_check_ptr}(compressed_g1: UInt384) -> (CompressedG1Flags, UInt384) {
    alloc_locals;

    let limb = compressed_g1.d3;

    // Extract bit 383
    let (compression_bit, remainder) = felt_divmod(limb, 0x800000000000000000000000);

    // Extract bit 382
    let (infinity_bit, remainder) = felt_divmod(remainder, 0x400000000000000000000000);

    // Extract bit 381
    let (sign_bit, uncompressed_x_limb) = felt_divmod(remainder, 0x200000000000000000000000);

    // Construct the x coordinate of the point
    let x_point = UInt384(
        d0=compressed_g1.d0, d1=compressed_g1.d1, d2=compressed_g1.d2, d3=uncompressed_x_limb
    );

    return (CompressedG1Flags(compression_bit, infinity_bit, sign_bit), x_point);
}


func pow2alloc251() -> (array: felt*) {
    let (data_address) = get_label_location(data);
    return (data_address,);

    data:
    dw 0x1;
    dw 0x2;
    dw 0x4;
    dw 0x8;
    dw 0x10;
    dw 0x20;
    dw 0x40;
    dw 0x80;
    dw 0x100;
    dw 0x200;
    dw 0x400;
    dw 0x800;
    dw 0x1000;
    dw 0x2000;
    dw 0x4000;
    dw 0x8000;
    dw 0x10000;
    dw 0x20000;
    dw 0x40000;
    dw 0x80000;
    dw 0x100000;
    dw 0x200000;
    dw 0x400000;
    dw 0x800000;
    dw 0x1000000;
    dw 0x2000000;
    dw 0x4000000;
    dw 0x8000000;
    dw 0x10000000;
    dw 0x20000000;
    dw 0x40000000;
    dw 0x80000000;
    dw 0x100000000;
    dw 0x200000000;
    dw 0x400000000;
    dw 0x800000000;
    dw 0x1000000000;
    dw 0x2000000000;
    dw 0x4000000000;
    dw 0x8000000000;
    dw 0x10000000000;
    dw 0x20000000000;
    dw 0x40000000000;
    dw 0x80000000000;
    dw 0x100000000000;
    dw 0x200000000000;
    dw 0x400000000000;
    dw 0x800000000000;
    dw 0x1000000000000;
    dw 0x2000000000000;
    dw 0x4000000000000;
    dw 0x8000000000000;
    dw 0x10000000000000;
    dw 0x20000000000000;
    dw 0x40000000000000;
    dw 0x80000000000000;
    dw 0x100000000000000;
    dw 0x200000000000000;
    dw 0x400000000000000;
    dw 0x800000000000000;
    dw 0x1000000000000000;
    dw 0x2000000000000000;
    dw 0x4000000000000000;
    dw 0x8000000000000000;
    dw 0x10000000000000000;
    dw 0x20000000000000000;
    dw 0x40000000000000000;
    dw 0x80000000000000000;
    dw 0x100000000000000000;
    dw 0x200000000000000000;
    dw 0x400000000000000000;
    dw 0x800000000000000000;
    dw 0x1000000000000000000;
    dw 0x2000000000000000000;
    dw 0x4000000000000000000;
    dw 0x8000000000000000000;
    dw 0x10000000000000000000;
    dw 0x20000000000000000000;
    dw 0x40000000000000000000;
    dw 0x80000000000000000000;
    dw 0x100000000000000000000;
    dw 0x200000000000000000000;
    dw 0x400000000000000000000;
    dw 0x800000000000000000000;
    dw 0x1000000000000000000000;
    dw 0x2000000000000000000000;
    dw 0x4000000000000000000000;
    dw 0x8000000000000000000000;
    dw 0x10000000000000000000000;
    dw 0x20000000000000000000000;
    dw 0x40000000000000000000000;
    dw 0x80000000000000000000000;
    dw 0x100000000000000000000000;
    dw 0x200000000000000000000000;
    dw 0x400000000000000000000000;
    dw 0x800000000000000000000000;
    dw 0x1000000000000000000000000;
    dw 0x2000000000000000000000000;
    dw 0x4000000000000000000000000;
    dw 0x8000000000000000000000000;
    dw 0x10000000000000000000000000;
    dw 0x20000000000000000000000000;
    dw 0x40000000000000000000000000;
    dw 0x80000000000000000000000000;
    dw 0x100000000000000000000000000;
    dw 0x200000000000000000000000000;
    dw 0x400000000000000000000000000;
    dw 0x800000000000000000000000000;
    dw 0x1000000000000000000000000000;
    dw 0x2000000000000000000000000000;
    dw 0x4000000000000000000000000000;
    dw 0x8000000000000000000000000000;
    dw 0x10000000000000000000000000000;
    dw 0x20000000000000000000000000000;
    dw 0x40000000000000000000000000000;
    dw 0x80000000000000000000000000000;
    dw 0x100000000000000000000000000000;
    dw 0x200000000000000000000000000000;
    dw 0x400000000000000000000000000000;
    dw 0x800000000000000000000000000000;
    dw 0x1000000000000000000000000000000;
    dw 0x2000000000000000000000000000000;
    dw 0x4000000000000000000000000000000;
    dw 0x8000000000000000000000000000000;
    dw 0x10000000000000000000000000000000;
    dw 0x20000000000000000000000000000000;
    dw 0x40000000000000000000000000000000;
    dw 0x80000000000000000000000000000000;
    dw 0x100000000000000000000000000000000;
    dw 0x200000000000000000000000000000000;
    dw 0x400000000000000000000000000000000;
    dw 0x800000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000000;
    dw 0x1000000000000000000000000000000000000000000000000000000000000;
    dw 0x2000000000000000000000000000000000000000000000000000000000000;
    dw 0x4000000000000000000000000000000000000000000000000000000000000;
    dw 0x8000000000000000000000000000000000000000000000000000000000000;
    dw 0x10000000000000000000000000000000000000000000000000000000000000;
    dw 0x20000000000000000000000000000000000000000000000000000000000000;
    dw 0x40000000000000000000000000000000000000000000000000000000000000;
    dw 0x80000000000000000000000000000000000000000000000000000000000000;
    dw 0x100000000000000000000000000000000000000000000000000000000000000;
    dw 0x200000000000000000000000000000000000000000000000000000000000000;
    dw 0x400000000000000000000000000000000000000000000000000000000000000;
    dw 0x800000000000000000000000000000000000000000000000000000000000000;
}

// func felt_divmod{range_check_ptr}(value, div) -> (q: felt, r: felt) {
//     let r = [range_check_ptr];
//     let q = [range_check_ptr + 1];
//     %{
//         from starkware.cairo.common.math_utils import assert_integer
//         assert_integer(ids.div)
//         if not (0 < ids.div <= PRIME):
//             raise ValueError(f'div={hex(ids.div)} is out of the valid range.')
//     %}
//     %{ ids.q, ids.r = divmod(ids.value, ids.div) %}
//     print_felt(q);
//     print_felt(r);
//     assert [range_check_ptr + 2] = div - 1 - r;
//     let range_check_ptr = range_check_ptr + 3;

//     assert value = q * div + r;
//     return (q, r);
// }
