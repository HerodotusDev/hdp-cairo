from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.memorizers.evm import EvmBlockTxMemorizer, EvmBlockReceiptMemorizer
from starkware.cairo.common.dict_access import DictAccess
from packages.eth_essentials.lib.utils import word_reverse_endian_64
from packages.eth_essentials.lib.mpt import verify_mpt_proof
from src.types import TransactionsInBlockDatalake, ChainInfo
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.decoders.transaction_decoder import TransactionDecoder, TransactionType
from src.decoders.receipt_decoder import ReceiptDecoder
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from src.tasks.fetch_trait import FetchTrait
from src.memorizers.reader import MemorizerReader, MemorizerId
from src.rlp import get_rlp_list_meta

namespace TX_IN_BLOCK_TYPES {
    const TX = 1;
    const RECEIPT = 2;
}

func init_txs_in_block{
    range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
}(input: felt*, input_bytes_len: felt) -> (res: TransactionsInBlockDatalake) {
    alloc_locals;

    // HeaderProp Input Layout:
    // 0-3: DatalakeCode.BlockSampled
    // 4-7: chain_id
    // 8-11: target_block
    // 12-15: start_index
    // 16-19: end_index
    // 20-23: increment
    // 24-27: included_types
    // 28-31: dynamic data offset
    // 32-35: dynamic data element count
    // 36-39: sampled_property (type, field)

    assert [input + 3] = 0x100000000000000;  // DatalakeCode.TxsInBlock == 1

    assert [input + 6] = 0;  // first 3 chunks of chain_id should be 0
    let (chain_id) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0;  // first 3 chunks of target_block should be 0
    let (target_block) = word_reverse_endian_64([input + 11]);

    assert [input + 14] = 0;  // first 3 chunks of start_index should be 0
    let (start_index) = word_reverse_endian_64([input + 15]);

    assert [input + 18] = 0;  // first 3 chunks of end_index should be 0
    let (end_index) = word_reverse_endian_64([input + 19]);

    assert [input + 22] = 0;  // first 3 chunks of increment should be 0
    let (increment) = word_reverse_endian_64([input + 23]);

    // Extract and add filter flags
    let (included_types) = alloc();
    let legacy = extract_byte_at_pos([input + 27], 4, pow2_array);
    assert included_types[TransactionType.LEGACY] = legacy;
    let eip2930 = extract_byte_at_pos([input + 27], 5, pow2_array);
    assert included_types[TransactionType.EIP2930] = eip2930;
    let eip1559 = extract_byte_at_pos([input + 27], 6, pow2_array);
    assert included_types[TransactionType.EIP1559] = eip1559;
    let eip4844 = extract_byte_at_pos([input + 27], 7, pow2_array);
    assert included_types[TransactionType.EIP4844] = eip4844;

    let type = extract_byte_at_pos([input + 36], 0, pow2_array);
    let property = extract_byte_at_pos([input + 36], 1, pow2_array);

    assert [input + 37] = 0;  // remaining chunks should be 0

    return (
        res=TransactionsInBlockDatalake(
            chain_id=chain_id,
            target_block=target_block,
            start_index=start_index,
            end_index=end_index,
            increment=increment,
            type=type,
            included_types=included_types,
            sampled_property=property,
        ),
    );
}

func fetch_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_tx_dict: DictAccess*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
    memorizer_handler: felt***,
}(chain_id: felt, datalake: TransactionsInBlockDatalake) -> (Uint256*, felt) {
    alloc_locals;
    let (data_points: Uint256*) = alloc();
    let memorizer_layout = chain_info.memorizer_layout;

    if (datalake.type == TX_IN_BLOCK_TYPES.TX) {
        with memorizer_layout {
            let data_points_len = abstract_fetch_tx_data_points(
                chain_id=chain_id, datalake=datalake, index=0, result_counter=0, data_points=data_points
            );
        }

        return (data_points, data_points_len);
    }

    if (datalake.type == TX_IN_BLOCK_TYPES.RECEIPT) {
        with memorizer_layout {
            let data_points_len = abstract_fetch_receipt_data_points(
                chain_id=chain_id, datalake=datalake, index=0, result_counter=0, data_points=data_points
            );
        }
        return (data_points, data_points_len);
    }

    assert 1 = 0;
    return (data_points, 0);
}

func abstract_fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_tx_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    memorizer_layout: felt,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    jmp abs fetch_trait.transaction_datalake.fetch_tx_data_points_ptr;
}

func abstract_fetch_receipt_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
    memorizer_handler: felt***,
    memorizer_layout: felt,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    jmp abs fetch_trait.transaction_datalake.fetch_receipt_data_points_ptr;
}

// DEFAULT IMPLEMENTATION OF FETCH TRAIT

func fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_tx_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    memorizer_handler: felt***,
    memorizer_layout: felt,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    alloc_locals;
    let current_tx_index = datalake.start_index + index * datalake.increment;

    local is_larger: felt;
    %{ ids.is_larger = 1 if ids.current_tx_index >= ids.datalake.end_index else 0 %}

    if (is_larger == 1) {
        assert [range_check_ptr] = current_tx_index - datalake.end_index;
        tempvar range_check_ptr = range_check_ptr + 1;
        return result_counter;
    }

    tempvar params = new(chain_id, datalake.target_block, current_tx_index);
    let (rlp) = MemorizerReader.read{
        dict_ptr=block_tx_dict, poseidon_ptr=poseidon_ptr
    }(memorizer_layout=memorizer_layout, memorizer_id=MemorizerId.BLOCK_TX, params=params);


    // let (rlp) = EvmBlockTxMemorizer.get(
    //     chain_id=chain_id, block_number=datalake.target_block, key_low=current_tx_index
    // );

    let (tx_type, rlp_start_offset) = TransactionDecoder.open_tx_envelope(rlp);

    if (datalake.included_types[tx_type] == 0) {
        return fetch_tx_data_points(
            chain_id=chain_id,
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let datapoint = TransactionDecoder.get_field(
        rlp, datalake.sampled_property, rlp_start_offset, tx_type
    );
    assert data_points[result_counter] = datapoint;
    return fetch_tx_data_points(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        result_counter=result_counter + 1,
        data_points=data_points,
    );
}

func fetch_receipt_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    block_receipt_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
    memorizer_handler: felt***,
    memorizer_layout: felt,
}(
    chain_id: felt,
    datalake: TransactionsInBlockDatalake,
    index: felt,
    result_counter: felt,
    data_points: Uint256*,
) -> felt {
    alloc_locals;
    let current_receipt_index = datalake.start_index + index * datalake.increment;

    local is_larger: felt;
    %{ ids.is_larger = 1 if ids.current_receipt_index >= ids.datalake.end_index else 0 %}

    if (is_larger == 1) {
        assert [range_check_ptr] = current_receipt_index - datalake.end_index;
        tempvar range_check_ptr = range_check_ptr + 1;
        return result_counter;
    }

    tempvar params = new(chain_id, datalake.target_block, current_receipt_index);
    let (rlp) = MemorizerReader.read{
        dict_ptr=block_receipt_dict, poseidon_ptr=poseidon_ptr
    }(memorizer_layout=memorizer_layout, memorizer_id=MemorizerId.BLOCK_RECEIPT, params=params);

    let (tx_type, rlp_start_offset) = ReceiptDecoder.open_receipt_envelope(rlp);

    if (datalake.included_types[tx_type] == 0) {
        return fetch_receipt_data_points(
            chain_id=chain_id,
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let datapoint = ReceiptDecoder.get_field(
        rlp, datalake.sampled_property, rlp_start_offset, tx_type, datalake.target_block
    );
    assert data_points[result_counter] = datapoint;
    return fetch_receipt_data_points(
        chain_id=chain_id,
        datalake=datalake,
        index=index + 1,
        result_counter=result_counter + 1,
        data_points=data_points,
    );
}
