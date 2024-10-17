from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.dict_access import DictAccess

from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams2
from src.decoders.evm.header_decoder import HeaderDecoder as EvmHeaderDecoder
from src.decoders.evm.account_decoder import AccountDecoder as EvmAccountDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder as EvmStorageSlotDecoder
from src.decoders.evm.transaction_decoder import TransactionDecoder as EvmTransactionDecoder
from src.decoders.evm.receipt_decoder import ReceiptDecoder as EvmReceiptDecoder

from src.chain_info import Layout

namespace EvmDecoderTarget {
    const UINT256 = 0;  // returns a Uint256
}

namespace EvmStateAccessType {
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const BLOCK_TX = 3;
    const BLOCK_RECEIPT = 4;
}

namespace EvmDecoder {
    func init() -> felt*** {
        // these decoders return a native word, so Uint256
        let (word_handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderDecoder.get_field);
        let (account_label) = get_label_location(EvmAccountDecoder.get_field);
        let (storage_label) = get_label_location(EvmStorageSlotDecoder.get_word);
        let (tx_label) = get_label_location(EvmTransactionDecoder.get_field);
        let (receipt_label) = get_label_location(EvmReceiptDecoder.get_field);

        assert word_handlers[EvmStateAccessType.HEADER] = header_label;
        assert word_handlers[EvmStateAccessType.ACCOUNT] = account_label;
        assert word_handlers[EvmStateAccessType.STORAGE] = storage_label;
        assert word_handlers[EvmStateAccessType.BLOCK_TX] = tx_label;
        assert word_handlers[EvmStateAccessType.BLOCK_RECEIPT] = receipt_label;

        // ToDo: Later one we can add other types of decoders, like for example RLP bytes or arrays

        let (evm_decoder_ptr: felt***) = alloc();
        assert evm_decoder_ptr[EvmDecoderTarget.UINT256] = word_handlers;

        return evm_decoder_ptr;
    }

    // A generic function for decoding values via the different EVM decoders.
    // The results are written to the output pointer and the result length in felts is returned.
    // Params:
    // - rlp: The RLP encoded data
    // - state_access_type: The id of the state to decode (EvmStateAccessType) -> E.g. EvmStateAccessType.Header
    // - field: The field of the specified state to decode (e.g HeaderField.GAS_LIMIT)
    // - decoder_target: The target format for the decoding (EvmDecoderTarget) -> E.g. EvmDecoderTarget.UINT256
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func decode{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        evm_decoder_ptr: felt***,
        output_ptr: felt*,
    }(
        rlp: felt*,
        state_access_type: felt,
        field: felt,
        block_number: felt,
        decoder_target: felt,
        as_be: felt,
    ) -> (result_len: felt) {
        alloc_locals;  // ToDo: solve output_ptr revoke and remove this

        let func_ptr = evm_decoder_ptr[decoder_target][state_access_type];
        if (decoder_target == EvmDecoderTarget.UINT256) {
            let (invoke_params, param_len) = _pack_decode_call_header(
                state_access_type, field, block_number, rlp
            );
            invoke(func_ptr, param_len, invoke_params);

            // Retrieve the results from [ap]
            let res_high = [ap - 1];
            let res_low = [ap - 2];
            let pow2_array = cast([ap - 3], felt*);
            let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
            let range_check_ptr = [ap - 5];

            if (as_be == 1) {
                let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
                assert output_ptr[0] = result.low;
                assert output_ptr[1] = result.high;

                return (result_len=2);
            } else {
                assert output_ptr[0] = res_low;
                assert output_ptr[1] = res_high;

                return (result_len=2);
            }
        } else {
            with_attr error_message("Selected EvmDecoderTarget not implemented") {
                assert 1 = 0;
            }

            return (result_len=0);
        }
    }

    // Prepares the call header for the call of the decoder function
    // Block number is only needed for receipts, but to keep the interface uniform, we pass it also for other states
    func _pack_decode_call_header{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        evm_decoder_ptr: felt***,
        output_ptr: felt*,
    }(state_access_type: felt, field: felt, block_number: felt, rlp: felt*) -> (
        invoke_params: felt*, param_len: felt
    ) {
        if (state_access_type == EvmStateAccessType.BLOCK_TX) {
            let (tx_type, rlp_start_offset) = EvmTransactionDecoder.open_tx_envelope(rlp);
            tempvar invoke_params = cast(
                new (
                    range_check_ptr, bitwise_ptr, pow2_array, rlp, field, rlp_start_offset, tx_type
                ),
                felt*,
            );
            return (invoke_params=invoke_params, param_len=7);
        }

        if (state_access_type == EvmStateAccessType.BLOCK_RECEIPT) {
            let (tx_type, rlp_start_offset) = EvmReceiptDecoder.open_receipt_envelope(rlp);
            tempvar invoke_params = cast(
                new (
                    range_check_ptr,
                    bitwise_ptr,
                    pow2_array,
                    rlp,
                    field,
                    rlp_start_offset,
                    tx_type,
                    block_number,
                ),
                felt*,
            );
            return (invoke_params=invoke_params, param_len=8);
        }

        tempvar invoke_params = cast(
            new (range_check_ptr, bitwise_ptr, pow2_array, rlp, field), felt*
        );
        return (invoke_params=invoke_params, param_len=5);
    }
}

// This namespace contains all the functions required for reading and decoding
// EVM states from the EVM memorizer
namespace EvmStateAccess {
    func init() -> felt** {
        let (evm_key_hasher_ptr: felt**) = alloc();
        let (header_label) = get_label_location(EvmHashParams2.header);
        let (account_label) = get_label_location(EvmHashParams2.account);
        let (storage_label) = get_label_location(EvmHashParams2.storage);
        let (tx_label) = get_label_location(EvmHashParams2.block_tx);
        let (receipt_label) = get_label_location(EvmHashParams2.block_receipt);

        assert evm_key_hasher_ptr[EvmStateAccessType.HEADER] = header_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.ACCOUNT] = account_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.STORAGE] = storage_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.BLOCK_TX] = tx_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.BLOCK_RECEIPT] = receipt_label;

        return evm_key_hasher_ptr;
    }

    // This function creates the memorizer key for the given state and params,
    // reads the corresponding RLP encoded state from the evm memorizer and
    // decodes the value. The result is written to the output pointer
    // Params:
    // - params: The parameters for the memorizer key
    // - state_access_type: The id of the state to decode (EvmStateAccessType) -> E.g. EvmStateAccessType.Header
    // - field: The field of the specified state to decode (e.g HeaderField.GAS_LIMIT)
    // - decoder_target: The target format for the decoding (EvmDecoderTarget) -> E.g. EvmDecoderTarget.UINT256
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func read_and_decode{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        evm_memorizer: DictAccess*,
        evm_decoder_ptr: felt***,
        evm_key_hasher_ptr: felt**,
        pow2_array: felt*,
        output_ptr: felt*,
    }(params: felt*, state_access_type: felt, field: felt, decoder_target: felt, as_be: felt) -> (
        result_len: felt
    ) {
        alloc_locals;  // ToDo: currently needed to retrieve the poseidon_ptr from the _compute_memorizer_key call. Find way to remove this

        let (memorizer_key) = _compute_memorizer_key(params, state_access_type);
        let (rlp) = EvmMemorizer.get(memorizer_key);

        // In EVM, the block number is always the second param. Ensure this doesnt change in the future
        let block_number = params[1];
        let (result_len) = EvmDecoder.decode(
            rlp, state_access_type, field, block_number, decoder_target, as_be
        );

        return (result_len=result_len);
    }

    // Computes the memorizer key by invoking the corresponding key hasher
    // Returns:
    // - The memorizer key
    func _compute_memorizer_key{poseidon_ptr: PoseidonBuiltin*, evm_key_hasher_ptr: felt**}(
        params: felt*, state_access_type: felt
    ) -> (key: felt) {
        tempvar invoke_params = cast(new (poseidon_ptr, params), felt*);
        let func_ptr = evm_key_hasher_ptr[state_access_type];
        invoke(func_ptr, 2, invoke_params);

        // Retrieve the results from [ap]
        let key = [ap - 1];
        let poseidon_ptr = cast([ap - 2], PoseidonBuiltin*);

        return (key=key);
    }
}

// Utils:

// The reader maps this function to memorizers that are not available in a specific memorizer layout
func invalid_memorizer_access{dict_ptr: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
    params: felt*
) {
    with_attr error_message("INVALID MEMORIZER ACCESS") {
        assert 1 = 0;
    }

    return ();
}
