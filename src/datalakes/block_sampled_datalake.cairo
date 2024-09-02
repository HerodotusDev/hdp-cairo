from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.alloc import alloc
from packages.eth_essentials.lib.utils import (
    word_reverse_endian_64,
    word_reverse_endian_16_RC,
    felt_divmod,
)
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.types import BlockSampledDataLake, ComputationalTask
from src.memorizers.evm import EvmHeaderMemorizer, EvmAccountMemorizer, EvmStorageMemorizer
from src.tasks.fetch_trait import FetchTrait
from src.decoders.evm.header_decoder import HeaderDecoder
from src.decoders.evm.account_decoder import AccountDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder
from src.decoders.decoder import ValueDecoder
from src.converter import le_address_chunks_to_felt
from src.rlp import le_chunks_to_uint256
from src.memorizers.reader import MemorizerReader, MemorizerId

namespace BlockSampledProperty {
    const HEADER = 1;
    const ACCOUNT = 2;
    const STORAGE_SLOT = 3;
}

// Creates a BlockSampledDataLake from the input bytes
func init_block_sampled{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(input: felt*, input_bytes_len: felt) -> (res: BlockSampledDataLake) {
    alloc_locals;

    let property_type = extract_byte_at_pos([input + 28], 0, pow2_array);

    let (chain_id, block_range_start, block_range_end, increment) = extract_constant_params{
        range_check_ptr=range_check_ptr
    }(input=input);

    let (properties) = alloc();
    // Decode properties
    if (property_type == BlockSampledProperty.HEADER) {
        // Header Input Layout:
        let chunk_one = word_reverse_endian_16_RC([input + 28]);

        assert [range_check_ptr] = 0x01ff - chunk_one;  // assert selected property_type matches input
        tempvar range_check_ptr = range_check_ptr + 1;

        // bootleg bitshift. 0x01 is a know value (property_type), the rest is the property
        assert [properties] = chunk_one - 0x100;

        return (
            res=BlockSampledDataLake(
                chain_id=chain_id,
                block_range_start=block_range_start,
                block_range_end=block_range_end,
                increment=increment,
                property_type=property_type,
                properties=properties,
            ),
        );
    }

    if (property_type == BlockSampledProperty.ACCOUNT) {
        // Account Input Layout:

        // extract & write field_idx
        let field_idx = extract_byte_at_pos([input + 30], 5, pow2_array);
        assert [properties] = field_idx;

        let (address) = extract_address{bitwise_ptr=bitwise_ptr}(
            chunk_one=[input + 28], chunk_two=[input + 29], chunk_three=[input + 30]
        );

        // write address to properties
        let (felt_address) = le_address_chunks_to_felt(address);
        assert [properties + 1] = felt_address;

        return (
            res=BlockSampledDataLake(
                chain_id=chain_id,
                block_range_start=block_range_start,
                block_range_end=block_range_end,
                increment=increment,
                property_type=property_type,
                properties=properties,
            ),
        );
    }
    if (property_type == BlockSampledProperty.STORAGE_SLOT) {
        // Account Slot Input Layout:

        let (address) = extract_address{bitwise_ptr=bitwise_ptr}(
            chunk_one=[input + 28], chunk_two=[input + 29], chunk_three=[input + 30]
        );

        // write address to properties
        let (felt_address) = le_address_chunks_to_felt(address);
        assert [properties] = felt_address;

        extract_and_write_slot{
            range_check_ptr=range_check_ptr, bitwise_ptr=bitwise_ptr, properties=properties
        }(chunks=input + 30);

        return (
            res=BlockSampledDataLake(
                chain_id=chain_id,
                block_range_start=block_range_start,
                block_range_end=block_range_end,
                increment=increment,
                property_type=property_type,
                properties=properties,
            ),
        );
    }

    assert 0 = 1;  // Invalid property_type
    let (prop) = alloc();
    return (res=BlockSampledDataLake(0, 0, 0, 0, 0, prop));
}

// Decodes slot from datalake definition and writes it to the properties array
func extract_and_write_slot{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, properties: felt*
}(chunks: felt*) {
    let divsor = 0x10000000000;
    let shifter = 0x1000000;
    let (acc) = alloc();

    let rlp_0 = [chunks];
    let (rlp_0_left, _) = felt_divmod(rlp_0, divsor);
    let rlp_1 = [chunks + 1];
    let (rlp_1_left, rlp_0_right) = felt_divmod(rlp_1, divsor);
    let word_0 = rlp_0_left * shifter + rlp_0_right;
    let rlp_2 = [chunks + 2];
    let (rlp_2_left, rlp_1_right) = felt_divmod(rlp_2, divsor);
    let word_1 = rlp_1_left * shifter + rlp_1_right;
    let rlp_3 = [chunks + 3];
    let (rlp_3_right, rlp_2_right) = felt_divmod(rlp_3, divsor);
    let word_2 = rlp_2_left * shifter + rlp_2_right;
    let rlp_4 = [chunks + 4];
    let (trash, rlp_3_left) = felt_divmod(rlp_4, divsor);
    let word_3 = rlp_3_left * shifter + rlp_3_right;

    assert [acc] = word_0;
    assert [acc + 1] = word_1;
    assert [acc + 2] = word_2;
    assert [acc + 3] = word_3;

    let slot_le = le_chunks_to_uint256(acc, 4, 32);
    let (slot_be) = uint256_reverse_endian(slot_le);
    %{ print("slot_be:", hex(ids.slot_be.high), hex(ids.slot_be.low)) %}

    assert [properties + 1] = slot_be.high;
    assert [properties + 2] = slot_be.low;

    return ();
}

// Evaluates the datalake definition and retrieves the data from the memorizer.
// Inputs:
// datalake: the datalake to sample
// Outputs:
// data_points: the data points sampled from the datalake
// data_points_len: the number of data points sampled
func fetch_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    account_dict: DictAccess*,
    storage_dict: DictAccess*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake) -> (Uint256*, felt) {
    alloc_locals;
    let (data_points: Uint256*) = alloc();

    if (datalake.property_type == BlockSampledProperty.HEADER) {
        let data_points_len = abstract_fetch_header_data_points(
            chain_id=chain_id, datalake=datalake, index=0, data_points=data_points
        );

        return (data_points, data_points_len);
    }

    if (datalake.property_type == BlockSampledProperty.ACCOUNT) {
        let data_points_len = abstract_fetch_account_data_points(
            chain_id=chain_id, datalake=datalake, index=0, data_points=data_points
        );

        return (data_points, data_points_len);
    }

    if (datalake.property_type == BlockSampledProperty.STORAGE_SLOT) {
        let data_points_len = abstract_fetch_storage_data_points(
            chain_id=chain_id, datalake=datalake, index=0, data_points=data_points
        );

        return (data_points, data_points_len);
    } else {
        assert 0 = 1;  // Invalid property_type
    }

    return (data_points, 0);
}

// Collects the account data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func abstract_fetch_account_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    account_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    jmp abs fetch_trait.block_sampled_datalake.fetch_account_data_points_ptr;
}

// Collects the storage data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func abstract_fetch_storage_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    jmp abs fetch_trait.block_sampled_datalake.fetch_storage_data_points_ptr;
}

// Collects the header data points defined in the datalake from the memorizer recursivly.
// Fills the data_points array with the values of the sampled property in LE
func abstract_fetch_header_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    jmp abs fetch_trait.block_sampled_datalake.fetch_header_data_points_ptr;
}

// Used for decoding the sampled property of block sampled headers.
// Accepted types: Account or AccountSlot
// data must be encoded as follows: abi.encodePacked(uint8(2), account, ...);
// Inputs:
// 3x le 8-byte chunks
// Output:
// id: the ID of the sampled property (2 for Account, 3 for AccountSlot)
// address: le 8-byte chunks
func extract_address{bitwise_ptr: BitwiseBuiltin*}(
    chunk_one: felt, chunk_two: felt, chunk_three: felt
) -> (address: felt*) {
    let (address: felt*) = alloc();

    // Example Input + operations:
    //  C1                   C2                   C3
    // '561c706ada385b 02', '87cb3fb0fcdc45 85', '3c 4ddbe56 5f'
    //                  ^                    ^    ^           ^
    //                 ID + rem       prepend C1  rem          prepend C2

    // 1. Extract ID
    assert bitwise_ptr[0].x = chunk_one;
    assert bitwise_ptr[0].y = 0x00000000000000ff;
    tempvar type_id = bitwise_ptr[0].x_and_y;

    // 2. Remove ID from C1 and right-shift
    let first_reduced = chunk_one - type_id;
    let first_reduced_div = first_reduced / 0x100;

    // 3. Extract last byte of C2 and prepend C1
    assert bitwise_ptr[1].x = chunk_two;
    assert bitwise_ptr[1].y = 0x00000000000000ff;
    tempvar lsb_c2 = bitwise_ptr[1].x_and_y;
    assert [address] = (first_reduced_div) + (2 ** 56) * lsb_c2;

    // 4. Remove last byte of C2 and right-shift
    let second_reduced = chunk_two - lsb_c2;
    let second_reduced_div = second_reduced / 0x100;

    // 5. Extract last byte of C3 and prepend C2
    assert bitwise_ptr[2].x = chunk_three;
    assert bitwise_ptr[2].y = 0x00000000000000ff;
    let shifted_prep_two = (2 ** 56) * bitwise_ptr[2].x_and_y;
    assert [address + 1] = (second_reduced_div) + shifted_prep_two;

    // 6. Extract remaining 4 address bytes and right-shift
    assert bitwise_ptr[3].x = chunk_three;
    assert bitwise_ptr[3].y = 0x0ffffffff00;
    assert [address + 2] = bitwise_ptr[3].x_and_y / 0x100;

    let bitwise_ptr = bitwise_ptr + 4 * BitwiseBuiltin.SIZE;
    return (address=address);
}

// Decodes the constant parameters of the block sampled data lake
// Inputs:
// input: le 8-byte chunks
// Outputs:
// block_range_start, block_range_end, increment
func extract_constant_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(input: felt*) -> (
    chain_id: felt, block_range_start: felt, block_range_end: felt, increment: felt
) {
    alloc_locals;
    // HeaderProp Input Layout:
    // 0-3: DatalakeCode.BlockSampled
    // 4-7: chain_id
    // 8-11: block_range_start
    // 12-15: block_range_end
    // 16-19: increment
    // 20-23: dynamic data offset
    // 24-27: dynamic data element count
    // 28-29: 01 + headerPropId
    assert [input + 3] = 0;  // DatalakeCode.BlockSampled == 0

    assert [input + 6] = 0;  // first 3 chunks of block_range_start should be 0
    let (chain_id) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0;  // first 3 chunks of block_range_start should be 0
    let (block_range_start) = word_reverse_endian_64([input + 11]);

    assert [input + 14] = 0;  // first 3 chunks of block_range_end should be 0
    let (block_range_end) = word_reverse_endian_64([input + 15]);

    assert [input + 18] = 0;  // first 3 chunks of increment should be 0
    let (increment) = word_reverse_endian_64([input + 19]);

    return (
        chain_id=chain_id,
        block_range_start=block_range_start,
        block_range_end=block_range_end,
        increment=increment,
    );
}

// DEFAULT IMPLEMENTATION OF FETCH TRAIT

// Collects the account data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func fetch_account_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    account_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    tempvar params = new (chain_id, current_block_number, [datalake.properties + 1]);
    let (rlp) = MemorizerReader.read{dict_ptr=account_dict, poseidon_ptr=poseidon_ptr}(
        memorizer_layout=memorizer_layout, memorizer_id=MemorizerId.ACCOUNT, params=params
    );

    let data_point = ValueDecoder.decode2(
        decoder_layout=memorizer_layout,
        decoder_id=MemorizerId.ACCOUNT,
        value=rlp,
        field=[datalake.properties],
        to_be=0,
    );

    assert [data_points + index * Uint256.SIZE] = data_point;

    return fetch_account_data_points(
        chain_id=chain_id, datalake=datalake, index=index + 1, data_points=data_points
    );
}

// Collects the storage data points defined in the datalake from the memorizer recursivly
// Inputs:
// datalake: the datalake to sample
// index: the current index of the data_points array
// data_points: outputs, array of values
func fetch_storage_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;

    let storage_slot = Uint256(low=[datalake.properties + 2], high=[datalake.properties + 1]);
    return fetch_storage_data_points_inner(chain_id, datalake, index, data_points, storage_slot);
}

func fetch_storage_data_points_inner{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    storage_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(
    chain_id: felt,
    datalake: BlockSampledDataLake,
    index: felt,
    data_points: Uint256*,
    storage_slot: Uint256,
) -> felt {
    alloc_locals;

    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    tempvar params = new (
        chain_id, current_block_number, [datalake.properties], storage_slot.high, storage_slot.low
    );
    let (rlp) = MemorizerReader.read{dict_ptr=storage_dict, poseidon_ptr=poseidon_ptr}(
        memorizer_layout=memorizer_layout, memorizer_id=MemorizerId.STORAGE, params=params
    );

    let data_point = ValueDecoder.decode2(
        decoder_layout=memorizer_layout, decoder_id=MemorizerId.STORAGE, value=rlp, field=0, to_be=0
    );
    assert [data_points + index * Uint256.SIZE] = data_point;

    return fetch_storage_data_points_inner(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        data_points=data_points,
        storage_slot=storage_slot,
    );
}

// Collects the header data points defined in the datalake from the memorizer recursivly.
// Fills the data_points array with the values of the sampled property in LE
func fetch_header_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    header_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    memorizer_layout: felt,
}(chain_id: felt, datalake: BlockSampledDataLake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;
    let current_block_number = datalake.block_range_start + index * datalake.increment;

    local exit_condition: felt;
    %{ ids.exit_condition = 1 if ids.current_block_number > ids.datalake.block_range_end else 0 %}
    if (exit_condition == 1) {
        assert [range_check_ptr] = (current_block_number - 1) - datalake.block_range_end;
        tempvar range_check_ptr = range_check_ptr + 1;
        return index;
    }

    tempvar params = new (chain_id, current_block_number);
    let (rlp) = MemorizerReader.read{dict_ptr=header_dict, poseidon_ptr=poseidon_ptr}(
        memorizer_layout=memorizer_layout, memorizer_id=MemorizerId.HEADER, params=params
    );

    let data_point = ValueDecoder.decode2(
        decoder_layout=memorizer_layout,
        decoder_id=MemorizerId.HEADER,
        value=rlp,
        field=[datalake.properties],
        to_be=0,
    );
    assert [data_points + index * Uint256.SIZE] = data_point;

    return fetch_header_data_points(
        chain_id=chain_id, datalake=datalake, index=index + 1, data_points=data_points
    );
}
