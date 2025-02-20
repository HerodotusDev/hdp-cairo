from src.decoders.evm.account_decoder import AccountDecoder as EvmAccountDecoder
from src.decoders.evm.header_decoder import HeaderDecoder as EvmHeaderDecoder
from src.decoders.evm.receipt_decoder import ReceiptDecoder as EvmReceiptDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder as EvmStorageSlotDecoder
from src.decoders.evm.transaction_decoder import TransactionDecoder as EvmTransactionDecoder
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256

from src.utils.chain_info import Layout

namespace EvmStateAccessType {
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const BLOCK_TX = 3;
    const BLOCK_RECEIPT = 4;
}

namespace EvmDecoder {
    func init() -> felt** {
        // these decoders return a native word, so Uint256
        let (handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderDecoder.get_field);
        let (account_label) = get_label_location(EvmAccountDecoder.get_field);
        let (storage_label) = get_label_location(EvmStorageSlotDecoder.get_word);
        let (tx_label) = get_label_location(EvmTransactionDecoder.get_field);
        let (receipt_label) = get_label_location(EvmReceiptDecoder.get_field);

        assert handlers[EvmStateAccessType.HEADER] = header_label;
        assert handlers[EvmStateAccessType.ACCOUNT] = account_label;
        assert handlers[EvmStateAccessType.STORAGE] = storage_label;
        assert handlers[EvmStateAccessType.BLOCK_TX] = tx_label;
        assert handlers[EvmStateAccessType.BLOCK_RECEIPT] = receipt_label;

        return handlers;
    }

    // A generic function for decoding values via the different EVM decoders.
    // The results are written to the output pointer and the result length in felts is returned.
    // Params:
    // - rlp: The RLP encoded data
    // - state_access_type: The id of the state to decode (EvmStateAccessType) -> E.g. EvmStateAccessType.Header
    // - field: The field of the specified state to decode (e.g HeaderField.GAS_LIMIT)
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func decode{
        range_check_ptr,
        bitwise_ptr: BitwiseBuiltin*,
        pow2_array: felt*,
        evm_decoder_ptr: felt**,
        output_ptr: felt*,
        keccak_ptr: KeccakBuiltin*,
    }(
        rlp: felt*,
        state_access_type: felt,
        field: felt,
        block_number: felt,
        chain_id: felt,
    ) -> () {
        alloc_locals;

        let func_ptr = evm_decoder_ptr[state_access_type];
        let (res_array, res_len) = call_decoder(
            func_ptr, state_access_type, field, block_number, chain_id, rlp
        );

        // Assert correct output_ptr values
        memcpy(dst=output_ptr, src=res_array, len=res_len);

        return ();
    }

    func call_decoder{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
    }(
        func_ptr: felt*,
        state_access_type: felt,
        field: felt,
        block_number: felt,
        chain_id: felt,
        rlp: felt*,
    ) -> (res_array: felt*, res_len: felt) {
        if (state_access_type == EvmStateAccessType.BLOCK_TX) {
            let (tx_type, rlp_start_offset) = EvmTransactionDecoder.open_tx_envelope(rlp);
            tempvar invoke_params = cast(
                new (
                    keccak_ptr,
                    range_check_ptr,
                    bitwise_ptr,
                    pow2_array,
                    rlp,
                    field,
                    rlp_start_offset,
                    tx_type,
                    chain_id,
                ),
                felt*,
            );
            invoke(func_ptr, 9, invoke_params);

            let res_array = cast([ap - 1], felt*);
            let res_len = [ap - 2];
            let pow2_array = cast([ap - 3], felt*);
            let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
            let range_check_ptr = [ap - 5];
            let keccak_ptr = cast([ap - 6], KeccakBuiltin*);

            return (res_array=res_array, res_len=res_len);
        }

        // ToDo: this (probably) is broken
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
                    chain_id,
                ),
                felt*,
            );
            invoke(func_ptr, 9, invoke_params);
            let res_array = cast([ap - 1], felt*);
            let res_len = [ap - 2];
            let pow2_array = cast([ap - 3], felt*);
            let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
            let range_check_ptr = [ap - 5];

            return (res_array=res_array, res_len=res_len);
        }

        tempvar invoke_params = cast(
            new (range_check_ptr, bitwise_ptr, pow2_array, rlp, field), felt*
        );

        invoke(func_ptr, 5, invoke_params);
        let res_array = cast([ap - 1], felt*);
        let res_len = [ap - 2];
        let pow2_array = cast([ap - 3], felt*);
        let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
        let range_check_ptr = [ap - 5];

        return (res_array=res_array, res_len=res_len);
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
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func read_and_decode{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        keccak_ptr: KeccakBuiltin*,
        evm_memorizer: DictAccess*,
        evm_decoder_ptr: felt**,
        evm_key_hasher_ptr: felt**,
        pow2_array: felt*,
        output_ptr: felt*,
    }(params: felt*, state_access_type: felt, field: felt) -> () {
        alloc_locals;  // ToDo: currently needed to retrieve the poseidon_ptr from the _compute_memorizer_key call. Find way to remove this

        let (memorizer_key) = _compute_memorizer_key(params, state_access_type);
        let (rlp) = EvmMemorizer.get(memorizer_key);

        // In EVM, the block number is always the second param. Ensure this doesnt change in the future
        let chain_id = params[0];
        let block_number = params[1];
        EvmDecoder.decode(
            rlp, state_access_type, field, block_number, chain_id
        );

        return ();
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
