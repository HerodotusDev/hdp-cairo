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
    let (state_roots: Uint256*) = alloc();
    let (account_proofs: felt***) = alloc();
    let (account_proofs_len: felt*) = alloc();
    let (account_proofs_bytes_len: felt**) = alloc();
    let (addresses_64_little: felt**) = alloc();

    local n_proofs: felt;
    %{
        from dotenv import load_dotenv
        import os
        from tools.py.storage_proof import get_account_proof, CairoAccountMPTProof

        load_dotenv()
        RPC_URL = os.getenv('RPC_URL')
        addresses = [0xd3cda913deb6f67967b99d67acdfa1712c293601, 0xaa3a45fEE87a6f6a86F8C62719354F967E4Ce7c2, 0xFb12899D8bf56E13288efA6b0E46358961af1aA9]
        block_numbers = [81326, 18821000, 15829204]

        def print_array(array_ptr, array_len):
            vals =[]
            for i in range(array_len):
                vals.append(memory[array_ptr + i])
            print([(hex(val), val.bit_length()) for val in vals])

        def write_uint256_array(ptr, array):
            counter = 0
            for uint in array:
                memory[ptr._reference_value+counter] = uint[0]
                memory[ptr._reference_value+counter+1] = uint[1]
                counter += 2

        def build_account_proofs(addresses, block_numbers, rpc_url):
            state_roots = []
            account_proofs = []
            account_proofs_bytes_len = []
            account_proofs_len = []
            addresses_64_little = []
            for address, block_number in zip(addresses, block_numbers):
                proof=get_account_proof(address, block_number, rpc_url)
                state_roots.append(proof.root)
                account_proofs.append(proof.proof)
                account_proofs_bytes_len.append(proof.proof_bytes_len)
                account_proofs_len.append(proof.proof_len)
                addresses_64_little.append(proof.address)
            return state_roots, account_proofs, account_proofs_bytes_len, account_proofs_len, addresses_64_little

        def write_account_proofs(state_roots, account_proofs, account_proofs_bytes_len, account_proofs_len, addresses_64_little):
            print(state_roots)
            print(account_proofs)
            write_uint256_array(ids.state_roots, state_roots)
            segments.write_arg(ids.account_proofs, account_proofs)
            segments.write_arg(ids.account_proofs_bytes_len, account_proofs_bytes_len)
            segments.write_arg(ids.account_proofs_len, account_proofs_len)
            segments.write_arg(ids.addresses_64_little, addresses_64_little)

        write_account_proofs(*build_account_proofs(addresses, block_numbers, RPC_URL))
        ids.n_proofs = len(addresses)
    %}

    let (pow2_array: felt*) = pow2alloc127();
    let (keys_little: Uint256*) = alloc();

    hash_n_addresses(
        addresses_64_little=addresses_64_little,
        keys_little=keys_little,
        n_addresses=n_proofs,
        index=0,
    );

    let (values: felt**) = alloc();
    let (values_lens: felt*) = alloc();

    verify_n_mpt_proofs(
        mpt_proofs=account_proofs,
        mpt_proofs_bytes_len=account_proofs_bytes_len,
        mpt_proofs_len=account_proofs_len,
        keys_little=keys_little,
        hashes_to_assert=state_roots,
        n_proofs=n_proofs,
        index=0,
        pow2_array=pow2_array,
        values=values,
        values_lens=values_lens,
    );

    return ();
}

func hash_n_addresses{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    addresses_64_little: felt**, keys_little: Uint256*, n_addresses: felt, index: felt
) {
    alloc_locals;
    if (index == n_addresses) {
        return ();
    } else {
        let (hash: Uint256) = keccak(addresses_64_little[index], 20);
        assert keys_little[index].low = hash.low;
        assert keys_little[index].high = hash.high;

        return hash_n_addresses(
            addresses_64_little=addresses_64_little,
            keys_little=keys_little,
            n_addresses=n_addresses,
            index=index + 1,
        );
    }
}

func verify_n_mpt_proofs{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}(
    mpt_proofs: felt***,
    mpt_proofs_bytes_len: felt**,
    mpt_proofs_len: felt*,
    keys_little: Uint256*,
    hashes_to_assert: Uint256*,
    n_proofs: felt,
    index: felt,
    pow2_array: felt*,
    values: felt**,
    values_lens: felt*,
) -> (values: felt**, values_lens: felt*) {
    alloc_locals;
    if (index == n_proofs) {
        return (values=values, values_lens=values_lens);
    } else {
        let (value: felt*, value_len: felt) = verify_mpt_proof(
            mpt_proof=mpt_proofs[index],
            mpt_proof_bytes_len=mpt_proofs_bytes_len[index],
            mpt_proof_len=mpt_proofs_len[index],
            key_little=keys_little[index],
            n_nibbles_already_checked=0,
            node_index=0,
            hash_to_assert=hashes_to_assert[index],
            pow2_array=pow2_array,
        );
        assert values_lens[index] = value_len;
        assert values[index] = value;
        return verify_n_mpt_proofs(
            mpt_proofs=mpt_proofs,
            mpt_proofs_bytes_len=mpt_proofs_bytes_len,
            mpt_proofs_len=mpt_proofs_len,
            keys_little=keys_little,
            hashes_to_assert=hashes_to_assert,
            n_proofs=n_proofs,
            index=index + 1,
            pow2_array=pow2_array,
            values=values,
            values_lens=values_lens,
        );
    }
}
