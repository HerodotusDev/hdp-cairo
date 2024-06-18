from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.memorizer import TransactionMemorizer, ReceiptMemorizer
from starkware.cairo.common.dict_access import DictAccess
from packages.eth_essentials.lib.utils import word_reverse_endian_64
from packages.eth_essentials.lib.mpt import verify_mpt_proof
from src.types import (
    TransactionsInBlockDatalake,
    Transaction,
    TransactionProof,
    Header,
    Receipt,
    ChainInfo,
)
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.decoders.transaction_decoder import TransactionDecoder, TransactionType
from src.decoders.receipt_decoder import ReceiptDecoder
from src.decoders.header_decoder import HeaderDecoder, HeaderField
from src.tasks.fetch_trait import FetchTrait

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
    // 4-7: target_block
    // 8-11: start_index
    // 12-15: end_index
    // 16-19: increment
    // 20-23: included_types
    // 24-27: dynamic data offset
    // 28-31: dynamic data element count
    // 32-35: sampled_property (type, field)
    assert [input + 3] = 0x100000000000000;  // DatalakeCode.TxsInBlock == 1

    assert [input + 6] = 0;  // first 3 chunks of target_block should be 0
    let (target_block) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0;  // first 3 chunks of start_index should be 0
    let (start_index) = word_reverse_endian_64([input + 11]);

    assert [input + 14] = 0;  // first 3 chunks of end_index should be 0
    let (end_index) = word_reverse_endian_64([input + 15]);

    assert [input + 18] = 0;  // first 3 chunks of increment should be 0
    let (increment) = word_reverse_endian_64([input + 19]);

    // Extract and add filter flags
    let (included_types) = alloc();
    let legacy = extract_byte_at_pos([input + 23], 4, pow2_array);
    assert included_types[TransactionType.LEGACY] = legacy;
    let eip2930 = extract_byte_at_pos([input + 23], 5, pow2_array);
    assert included_types[TransactionType.EIP2930] = eip2930;
    let eip1559 = extract_byte_at_pos([input + 23], 6, pow2_array);
    assert included_types[TransactionType.EIP1559] = eip1559;
    let eip4844 = extract_byte_at_pos([input + 23], 7, pow2_array);
    assert included_types[TransactionType.EIP4844] = eip4844;

    let type = extract_byte_at_pos([input + 32], 0, pow2_array);
    let property = extract_byte_at_pos([input + 32], 1, pow2_array);

    assert [input + 33] = 0;  // remaining chunks should be 0

    return (
        res=TransactionsInBlockDatalake(
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
    transaction_dict: DictAccess*,
    transactions: Transaction*,
    receipts: Receipt*,
    receipt_dict: DictAccess*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
}(datalake: TransactionsInBlockDatalake) -> (Uint256*, felt) {
    alloc_locals;
    let (data_points: Uint256*) = alloc();

    if (datalake.type == TX_IN_BLOCK_TYPES.TX) {
        let data_points_len = abstract_fetch_tx_data_points(
            datalake=datalake, index=0, result_counter=0, data_points=data_points
        );

        return (data_points, data_points_len);
    }

    if (datalake.type == TX_IN_BLOCK_TYPES.RECEIPT) {
        let data_points_len = abstract_fetch_receipt_data_points(
            datalake=datalake, index=0, result_counter=0, data_points=data_points
        );
        return (data_points, data_points_len);
    }

    assert 1 = 0;
    return (data_points, 0);
}

func abstract_fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    transaction_dict: DictAccess*,
    transactions: Transaction*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(
    datalake: TransactionsInBlockDatalake, index: felt, result_counter: felt, data_points: Uint256*
) -> felt {
    jmp abs fetch_trait.transaction_datalake.fetch_tx_data_points_ptr;
}

func abstract_fetch_receipt_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    receipt_dict: DictAccess*,
    receipts: Receipt*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
}(
    datalake: TransactionsInBlockDatalake, index: felt, result_counter: felt, data_points: Uint256*
) -> felt {
    jmp abs fetch_trait.transaction_datalake.fetch_receipt_data_points_ptr;
}

// DEFAULT IMPLEMENTATION OF FETCH TRAIT

func fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    transaction_dict: DictAccess*,
    transactions: Transaction*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
}(
    datalake: TransactionsInBlockDatalake, index: felt, result_counter: felt, data_points: Uint256*
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

    let (tx) = TransactionMemorizer.get(datalake.target_block, current_tx_index);

    if (datalake.included_types[tx.type] == 0) {
        return fetch_tx_data_points(
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let datapoint = TransactionDecoder.get_field(tx, datalake.sampled_property);
    assert data_points[result_counter] = datapoint;
    return fetch_tx_data_points(
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
    receipt_dict: DictAccess*,
    receipts: Receipt*,
    pow2_array: felt*,
    fetch_trait: FetchTrait,
    chain_info: ChainInfo,
}(
    datalake: TransactionsInBlockDatalake, index: felt, result_counter: felt, data_points: Uint256*
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

    let (receipt) = ReceiptMemorizer.get(datalake.target_block, current_receipt_index);

    if (datalake.included_types[receipt.type] == 0) {
        return fetch_receipt_data_points(
            datalake=datalake,
            index=index + 1,
            result_counter=result_counter,
            data_points=data_points,
        );
    }

    let datapoint = ReceiptDecoder.get_field(receipt, datalake.sampled_property);
    assert data_points[result_counter] = datapoint;
    return fetch_receipt_data_points(
        datalake=datalake,
        index=index + 1,
        result_counter=result_counter + 1,
        data_points=data_points,
    );
}
