from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.dict_access import DictAccess

from src.memorizers.starknet.memorizer import StarknetMemorizer, StarknetHashParams2
from src.decoders.starknet.header_decoder import StarknetHeaderDecoder
from src.chain_info import Layout

namespace StarknetDecoderTarget {
    const FELT = 0;  // returns a felt
}

namespace StarknetStateAccessType {
    const HEADER = 0;
    const STORAGE = 1;
}

namespace StarknetDecoder {
    func init() -> felt*** {
        // these decoders return a native word, so felt
        let (word_handlers: felt**) = alloc();
        let (header_label) = get_label_location(StarknetHeaderDecoder.get_field);
        let (passthrough_label) = get_label_location(_decoder_passthrough);

        assert word_handlers[StarknetStateAccessType.HEADER] = header_label;
        // Since storage slots always return a single felt, we can use a passthrough decoder for them
        assert word_handlers[StarknetStateAccessType.STORAGE] = passthrough_label;

        let (starknet_decoder_ptr: felt***) = alloc();
        assert starknet_decoder_ptr[StarknetDecoderTarget.FELT] = word_handlers;

        return starknet_decoder_ptr;
    }

    // A generic function for decoding values via the different EVM decoders.
    // The results are written to the output pointer and the result length in felts is returned.
    // Params:
    // - rlp: The RLP encoded data
    // - state_access_type: The id of the state to decode (StarknetStateAccessType) -> E.g. StarknetStateAccessType.Header
    // - field: The field of the specified state to decode (e.g HeaderField.GAS_LIMIT)
    // - decoder_target: The target format for the decoding (StarknetDecoderTarget) -> E.g. StarknetDecoderTarget.UINT256
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func decode{range_check_ptr, starknet_decoder_ptr: felt***, output_ptr: felt*}(
        rlp: felt*,
        state_access_type: felt,
        field: felt,
        block_number: felt,
        decoder_target: felt,
        as_be: felt,
    ) -> (result_len: felt) {
        alloc_locals;  // ToDo: solve output_ptr revoke and remove this

        let func_ptr = starknet_decoder_ptr[decoder_target][state_access_type];
        if (decoder_target == StarknetDecoderTarget.FELT) {
            let (invoke_params, param_len) = _pack_decode_call_header(
                state_access_type, field, block_number, rlp
            );
            invoke(func_ptr, param_len, invoke_params);

            // Retrieve the results from [ap]
            let res = [ap - 1];
            let range_check_ptr = [ap - 2];

            if (as_be == 1) {
                assert output_ptr[0] = res;

                return (result_len=1);
            } else {
                with_attr error_message("LE decoding currently not supported for Starknet") {
                    assert 1 = 0;
                }
            }
        } else {
            with_attr error_message("Selected StarknetDecoderTarget not implemented") {
                assert 1 = 0;
            }

            return (result_len=0);
        }
    }

    // Prepares the call header for the call of the decoder function
    func _pack_decode_call_header{range_check_ptr}(
        state_access_type: felt, field: felt, data: felt*
    ) -> (invoke_params: felt*, param_len: felt) {
        // Since we use the passthrough decoder for storage, we only need to pass the data
        if (state_access_type == StarknetStateAccessType.STORAGE) {
            tempvar invoke_params = cast(new (range_check_ptr, data), felt*);
            return (invoke_params=invoke_params, param_len=2);
        }

        tempvar invoke_params = cast(new (range_check_ptr, data, field), felt*);
        return (invoke_params=invoke_params, param_len=3);
    }
}

// This namespace contains all the functions required for reading and decoding
// EVM states from the EVM memorizer
namespace StarknetStateAccess {
    func init() -> felt** {
        let (starknet_key_hasher_ptr: felt**) = alloc();
        let (header_label) = get_label_location(StarknetHashParams2.header);
        let (storage_label) = get_label_location(StarknetHashParams2.storage);

        assert starknet_key_hasher_ptr[StarknetStateAccessType.HEADER] = header_label;
        assert starknet_key_hasher_ptr[StarknetStateAccessType.STORAGE] = storage_label;

        return starknet_key_hasher_ptr;
    }

    // This function creates the memorizer key for the given state and params,
    // reads the corresponding RLP encoded state from the evm memorizer and
    // decodes the value. The result is written to the output pointer
    // Params:
    // - params: The parameters for the memorizer key
    // - state_access_type: The id of the state to decode (StarknetStateAccessType) -> E.g. StarknetStateAccessType.Header
    // - field: The field of the specified state to decode (e.g HeaderField.GAS_LIMIT)
    // - decoder_target: The target format for the decoding (StarknetDecoderTarget) -> E.g. StarknetDecoderTarget.UINT256
    // - as_be: Whether to return the result as big endian
    // Returns:
    // - The length of the result in felts
    func read_and_decode{
        range_check_ptr,
        starknet_memorizer: DictAccess*,
        starknet_decoder_ptr: felt***,
        starknet_key_hasher_ptr: felt**,
        output_ptr: felt*,
    }(params: felt*, state_access_type: felt, field: felt, decoder_target: felt, as_be: felt) -> (
        result_len: felt
    ) {
        alloc_locals;  // ToDo: currently needed to retrieve the poseidon_ptr from the _compute_memorizer_key call. Find way to remove this

        let (memorizer_key) = _compute_memorizer_key(params, state_access_type);
        let (rlp) = StarknetMemorizer.get(memorizer_key);

        // In EVM, the block number is always the second param. Ensure this doesnt change in the future
        let block_number = params[1];
        let (result_len) = StarknetDecoder.decode(
            rlp, state_access_type, field, block_number, decoder_target, as_be
        );

        return (result_len=result_len);
    }

    // Computes the memorizer key by invoking the corresponding key hasher
    // Returns:
    // - The memorizer key
    func _compute_memorizer_key{poseidon_ptr: PoseidonBuiltin*, starknet_key_hasher_ptr: felt**}(
        params: felt*, state_access_type: felt
    ) -> (key: felt) {
        tempvar invoke_params = cast(new (poseidon_ptr, params), felt*);
        let func_ptr = starknet_key_hasher_ptr[state_access_type];
        invoke(func_ptr, 2, invoke_params);

        // Retrieve the results from [ap]
        let key = [ap - 1];
        let poseidon_ptr = cast([ap - 2], PoseidonBuiltin*);

        return (key=key);
    }
}

// Storage slots always return a single felt, so we dont need to decode anything.
// To keep the interface uniform, we will call this function when decoding
func _decoder_passthrough{range_check_ptr}(data: felt*) -> (result: felt) {
    return (result=data[0]);
}
