%builtins output range_check bitwise keccak

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.registers import get_fp_and_pc

from src.libs.utils import pow2alloc127
from src.libs.mpt import verify_mpt_proof

// BLANK HASH BIG = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
// BLANK HASH LITTLE = 5094972239999916

func main{
    output_ptr: felt*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*
}() {
    alloc_locals;
    local state_root_little: Uint256;
    let (account_proof: felt**) = alloc();
    local account_proof_len: felt;
    let (account_proof_bytes_len: felt*) = alloc();
    let (address_64_little: felt*) = alloc();
    %{
        from dotenv import load_dotenv
        import os
        from tools.py.storage_proof import get_account_proof, CairoAccountMPTProof

        load_dotenv()
        RPC_URL = os.getenv('RPC_URL_MAINNET')
        address = 0xd3cda913deb6f67967b99d67acdfa1712c293601
        block_number = 81326

        def print_array(array_ptr, array_len):
            vals =[]
            for i in range(array_len):
                vals.append(memory[array_ptr + i])
            print([(hex(val), val.bit_length()) for val in vals])

        ap:CairoAccountMPTProof = get_account_proof(address, block_number, RPC_URL)

        ids.state_root_little.low = ap.root[0]
        ids.state_root_little.high = ap.root[1]
        segments.write_arg(ids.address_64_little, ap.address)
        segments.write_arg(ids.account_proof, ap.proof)
        ids.account_proof_len = ap.proof_len
        segments.write_arg(ids.account_proof_bytes_len, ap.proof_bytes_len)
    %}

    let (pow2_array: felt*) = pow2alloc127();

    let (key_little: Uint256) = keccak(address_64_little, 20);

    let (value: felt*, value_len: felt) = verify_mpt_proof(
        mpt_proof=account_proof,
        mpt_proof_bytes_len=account_proof_bytes_len,
        mpt_proof_len=account_proof_len,
        key_little=key_little,
        n_nibbles_already_checked=0,
        node_index=0,
        hash_to_assert=state_root_little,
        pow2_array=pow2_array,
    );

    return ();
}
