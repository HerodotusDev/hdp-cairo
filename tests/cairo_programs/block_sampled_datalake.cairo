%builtins range_check bitwise keccak
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin, BitwiseBuiltin, KeccakBuiltin
from packages.eth_essentials.lib.utils import pow2alloc128
from src.datalakes.block_sampled_datalake import init_block_sampled
from tests.cairo_programs.test_vectors import BlockSampledDataLakeMocker
from src.types import BlockSampledDataLake

func main{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*}() {
    let pow2_array: felt* = pow2alloc128();

    test_block_sampled_datalake_decoding{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        keccak_ptr=keccak_ptr,
        pow2_array=pow2_array,
    }();

    return ();
}

func test_block_sampled_datalake_decoding{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}() {
    alloc_locals;

    let (
        header_input, header_input_bytes_len, header_expected_datalake, header_property_type
    ) = BlockSampledDataLakeMocker.get_header_property();
    let (header_datalake) = init_block_sampled(header_input, header_input_bytes_len);
    block_sampled_datalake_eq(header_datalake, header_expected_datalake, header_property_type);

    let (
        account_input, account_input_bytes_len, account_expected_datalake, account_property_type
    ) = BlockSampledDataLakeMocker.get_account_property();
    let (account_datalake) = init_block_sampled(account_input, account_input_bytes_len);
    block_sampled_datalake_eq(account_datalake, account_expected_datalake, account_property_type);

    let (
        storage_input, storage_input_bytes_len, storage_expected_datalake, storage_property_type
    ) = BlockSampledDataLakeMocker.get_storage_property();
    let (storage_datalake) = init_block_sampled(storage_input, storage_input_bytes_len);
    block_sampled_datalake_eq(storage_datalake, storage_expected_datalake, storage_property_type);

    return ();
}

func block_sampled_datalake_eq(
    a: BlockSampledDataLake, b: BlockSampledDataLake, property_type: felt
) {
    assert a.block_range_start = b.block_range_start;
    assert a.block_range_end = b.block_range_end;
    assert a.increment = b.increment;
    assert a.property_type = b.property_type;

    if (property_type == 1) {
        assert a.properties[0] = b.properties[0];
    }

    if (property_type == 2) {
        assert a.properties[0] = b.properties[0];
        assert a.properties[1] = b.properties[1];
    }

    if (property_type == 3) {
        assert a.properties[0] = b.properties[0];
        assert a.properties[1] = b.properties[1];
        assert a.properties[2] = b.properties[2];
    }

    return ();
}
