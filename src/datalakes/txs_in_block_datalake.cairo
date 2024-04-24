from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.builtin_keccak.keccak import keccak
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.alloc import alloc
from src.memorizer import HeaderMemorizer, TransactionMemorizer
from starkware.cairo.common.dict_access import DictAccess
from packages.eth_essentials.lib.utils import word_reverse_endian_64
from packages.eth_essentials.lib.mpt import verify_mpt_proof
from src.types import TransactionsInBlockDatalake, Transaction, TransactionProof, Header
from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.decoders.transaction_decoder import TransactionDecoder
from src.decoders.header_decoder import HeaderDecoder, HEADER_FIELD

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
    // 8-11: increment
    // 12-15: dynamic data offset
    // 16-19: dynamic data element count
    // 20-23: sampled_property (type, field)
    assert [input + 3] = 0x100000000000000;  // DatalakeCode.TxsInBlock == 1

    assert [input + 6] = 0;  // first 3 chunks of target_block should be 0
    let (target_block) = word_reverse_endian_64([input + 7]);

    assert [input + 10] = 0;  // first 3 chunks of increment should be 0
    let (increment) = word_reverse_endian_64([input + 11]);

    let type = extract_byte_at_pos([input + 20], 0, pow2_array);
    let property = extract_byte_at_pos([input + 20], 1, pow2_array);  // first chunk cointains type + property

    // validate_block_tx_count(target_block);

    assert [input + 21] = 0;  // remaining chunks should be 0

    return (
        res=TransactionsInBlockDatalake(
            target_block=target_block, increment=increment, type=type, sampled_property=property
        ),
    );
}

// func validate_block_tx_count{
//     range_check_ptr,
//     bitwise_ptr: BitwiseBuiltin*,
//     keccak_ptr: KeccakBuiltin*,
//     header_dict: DictAccess*,
//     headers: Header*,
//     pow2_array: felt*,
// } (target_block: felt) -> felt {
//     alloc_locals;

// local key: Uint256;
//     let (proof: felt**) = alloc();
//     local proof_len: felt;
//     let (proof_bytes_len: felt*) = alloc();

// %{
//         proof = next((item for item in program_input['last_tx_markers'] if item['block_number'] == ids.target_block), None)
//         print(proof)
//         segments.write_arg(ids.proof_bytes_len, proof["proof_bytes_len"])
//         segments.write_arg(ids.proof, nested_hex_to_int_array(proof["proof"]))
//         ids.proof_len = len(proof["proof"])
//         ids.key.low = hex_to_int(proof["key"]["low"])
//         ids.key.high = hex_to_int(proof["key"]["high"])
//     %}

// let header = HeaderMemorizer.get(target_block);
//     let tx_root = HeaderDecoder.get_field(header.rlp, HEADER_FIELD.TRANSACTION_ROOT);

// let (tx_item, tx_item_bytes_len) = verify_mpt_proof(
//         mpt_proof=proof,
//         mpt_proof_bytes_len=proof_bytes_len,
//         mpt_proof_len=proof_len,
//         key_little=key,
//         n_nibbles_already_checked=0,
//         node_index=0,
//         hash_to_assert=tx_root,
//         pow2_array=pow2_array,
//     );

// %{
//         print("tx_item", hex(memory[ids.tx_item]))
//     %}

// return 0;

// }

func fetch_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    transaction_dict: DictAccess*,
    transactions: Transaction*,
    pow2_array: felt*,
}(datalake: TransactionsInBlockDatalake) -> (Uint256*, felt) {
    alloc_locals;
    let (data_points: Uint256*) = alloc();

    if (datalake.type == TX_IN_BLOCK_TYPES.TX) {
        let data_points_len = fetch_tx_data_points(
            datalake=datalake, index=0, data_points=data_points
        );

        return (data_points, data_points_len);
    }

    if (datalake.type == TX_IN_BLOCK_TYPES.RECEIPT) {
        assert 1 = 0;
    }

    assert 1 = 0;
    return (data_points, 0);
}

func fetch_tx_data_points{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    transaction_dict: DictAccess*,
    transactions: Transaction*,
    pow2_array: felt*,
}(datalake: TransactionsInBlockDatalake, index: felt, data_points: Uint256*) -> felt {
    alloc_locals;
    %{ print("index;", ids.index) %}
    let (tx) = TransactionMemorizer.get(datalake.target_block, index * datalake.increment);
    let datapoint = TransactionDecoder.get_field(tx, datalake.sampled_property);
    assert data_points[index] = datapoint;

    // ToDo: THIS IS UNSOUND!
    local last: felt;
    %{ ids.last = len(program_input["transactions"]) %}
    if (index + 1 == last) {
        return index + 1;
    }

    return fetch_tx_data_points(datalake=datalake, index=index + 1, data_points=data_points);
}
