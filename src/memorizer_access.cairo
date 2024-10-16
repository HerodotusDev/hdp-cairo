from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.dict_access import DictAccess

from src.memorizers.evm import (
    EvmHeaderMemorizer,
    EvmAccountMemorizer,
    EvmStorageMemorizer,
    EvmBlockTxMemorizer,
    EvmBlockReceiptMemorizer,
)
from src.memorizers.starknet import StarknetHeaderMemorizer
from src.decoders.evm.header_decoder import HeaderDecoder as EvmHeaderDecoder
from src.decoders.evm.account_decoder import AccountDecoder as EvmAccountDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder as EvmStorageSlotDecoder
from src.decoders.evm.transaction_decoder import TransactionDecoder as EvmTransactionDecoder
from src.decoders.evm.receipt_decoder import ReceiptDecoder as EvmReceiptDecoder
from src.decoders.starknet.header_decoder import StarknetHeaderDecoder
from src.chain_info import Layout

namespace DictId {
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const BLOCK_TX = 3;
    const BLOCK_RECEIPT = 4;
}

namespace OutputType {
    const FELT = 0;
    const UINT256 = 1;
    const FELT_ARRAY = 2;
    const UINT256_ARRAY = 3;
}

// These functions are used to perform reads perform memorizer reads from built-in hdp agg_fns.
// These shouldnt be used by the bootloader directly!
namespace InternalMemorizerReader {
    func init() -> felt*** {
        let (evm_handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderMemorizer.get);
        let (account_label) = get_label_location(EvmAccountMemorizer.get);
        let (storage_label) = get_label_location(EvmStorageMemorizer.get);
        let (block_tx_label) = get_label_location(EvmBlockTxMemorizer.get);
        let (block_receipt_label) = get_label_location(EvmBlockReceiptMemorizer.get);

        assert evm_handlers[DictId.HEADER] = header_label;
        assert evm_handlers[DictId.ACCOUNT] = account_label;
        assert evm_handlers[DictId.STORAGE] = storage_label;
        assert evm_handlers[DictId.BLOCK_TX] = block_tx_label;
        assert evm_handlers[DictId.BLOCK_RECEIPT] = block_receipt_label;

        let (sn_handlers: felt**) = alloc();
        let (header_label) = get_label_location(StarknetHeaderMemorizer.get);
        assert sn_handlers[DictId.HEADER] = header_label;

        let (handlers: felt***) = alloc();
        assert handlers[Layout.EVM] = evm_handlers;
        assert handlers[Layout.STARKNET] = sn_handlers;

        return handlers;
    }

    func read{dict_ptr: DictAccess*, poseidon_ptr: PoseidonBuiltin*, memorizer_handler: felt***}(
        layout: felt, dict_id: felt, params: felt*
    ) -> (res: felt*) {
        let func_ptr = memorizer_handler[layout][dict_id];

        tempvar invoke_params = cast(new (dict_ptr, poseidon_ptr, params), felt*);
        invoke(func_ptr, 3, invoke_params);

        let res = cast([ap - 1], felt*);
        let poseidon_ptr = cast([ap - 2], PoseidonBuiltin*);
        let dict_ptr = cast([ap - 3], DictAccess*);

        return (res=res);
    }
}

// These functions should be used to decode values from the hdp agg_fns.
// These shouldnt be used by the bootloader directly!
namespace InternalValueDecoder {
    func init() -> felt*** {
        let (evm_handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderDecoder.get_field);
        let (account_label) = get_label_location(EvmAccountDecoder.get_field);
        let (storage_label) = get_label_location(EvmStorageSlotDecoder.get_word);
        let (tx_label) = get_label_location(EvmTransactionDecoder.get_field);
        let (receipt_label) = get_label_location(EvmReceiptDecoder.get_field);

        assert evm_handlers[DictId.HEADER] = header_label;
        assert evm_handlers[DictId.ACCOUNT] = account_label;
        assert evm_handlers[DictId.STORAGE] = storage_label;
        assert evm_handlers[DictId.BLOCK_TX] = tx_label;
        assert evm_handlers[DictId.BLOCK_RECEIPT] = receipt_label;

        let (sn_handlers: felt**) = alloc();
        let (header_label) = get_label_location(StarknetHeaderDecoder.get_field_uint256);
        assert sn_handlers[DictId.HEADER] = header_label;

        let (handlers: felt***) = alloc();
        assert handlers[Layout.EVM] = evm_handlers;
        assert handlers[Layout.STARKNET] = sn_handlers;

        return handlers;
    }

    // Decodes all data types, except for evm receipts, writes them to the output ptr and returns the return type
    func decode{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, decoder_handler: felt***
    }(
        layout: felt,
        dict_id: felt,
        encoded_data: felt*,
        field: felt,
        output_ptr: felt*,
        to_be: felt,
    ) -> felt {
        if (layout == Layout.EVM) {
            if (dict_id == DictId.BLOCK_RECEIPT) {
                assert 1 = 0;  // Not implemented
            }
        }

        let func_ptr = decoder_handler[layout][dict_id];
        if(layout == Layout.EVM) {
            let (invoke_params, param_len) = pack_evm_decode_params(dict_id, encoded_data, field);
            invoke(func_ptr, param_len, invoke_params);

            // Retrieve the results from [ap]
            let res_high = [ap - 1];
            let res_low = [ap - 2];
            let pow2_array = cast([ap - 3], felt*);
            let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
            let range_check_ptr = [ap - 5];

            if (to_be == 1) {
                let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
                assert output_ptr[0] = result.high;
                assert output_ptr[1] = result.low;

                return OutputType.UINT256;
            } else {
                assert output_ptr[0] = res_high;
                assert output_ptr[1] = res_low;

                return OutputType.UINT256;
            }
        } else {
            let (invoke_params, param_len) = pack_sn_decode_params(encoded_data, field);
            invoke(func_ptr, param_len, invoke_params);

            let res_high = [ap - 1];
            let res_low = [ap - 2];
            let range_check_ptr = [ap - 3];

            if (to_be == 1) {
                assert output_ptr[0] = res_high;
                assert output_ptr[1] = res_low;

                return OutputType.UINT256;
            } else {
                let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
                assert output_ptr[0] = result.high;
                assert output_ptr[1] = result.low;

                return OutputType.UINT256;
            }
        }
    }

    // Decodes all data types, except for evm receipts, and returns them as a Uint256
    func decode2{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, decoder_handler: felt***
    }(layout: felt, dict_id: felt, encoded_data: felt*, field: felt, to_be: felt) -> Uint256 {
        let func_ptr = decoder_handler[layout][dict_id];

        // since we need to pass the block height, use dedicated function
        if (layout == Layout.EVM) {
            if (dict_id == DictId.BLOCK_RECEIPT) {
                assert 1 = 0;  // Not implemented
            }
        }

        if(layout == Layout.EVM) {
            let (invoke_params, param_len) = pack_evm_decode_params(dict_id, encoded_data, field);
            invoke(func_ptr, param_len, invoke_params);

            // Retrieve the results from [ap]
            let res_high = [ap - 1];
            let res_low = [ap - 2];
            let pow2_array = cast([ap - 3], felt*);
            let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
            let range_check_ptr = [ap - 5];

            let result = Uint256(low=res_low, high=res_high);
            if (to_be == 1) {
                let (be_result) = uint256_reverse_endian(num=result);
                return be_result;
            } else {
                return result;
            }
        } else {
            let (invoke_params, param_len) = pack_sn_decode_params(encoded_data, field);
            invoke(func_ptr, param_len, invoke_params);

            let res_high = [ap - 1];
            let res_low = [ap - 2];
            let range_check_ptr = [ap - 3];

            let result = Uint256(low=res_low, high=res_high);

            if (to_be == 1) {
                return result;
            } else {
                let (le_result) = uint256_reverse_endian(result);
                
                return le_result;
            }
        }
    }

    // Since we need to pass the block height, use dedicated function
    func decode_evm_receipt{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, decoder_handler: felt***
    }(encoded_data: felt*, field: felt, block_number: felt, output: felt*, as_be: felt) -> felt {
        let func_ptr = decoder_handler[Layout.EVM][DictId.BLOCK_RECEIPT];

        let (tx_type, rlp_start_offset) = EvmReceiptDecoder.open_receipt_envelope(encoded_data);
        tempvar invoke_params = cast(
            new (
                range_check_ptr,
                bitwise_ptr,
                pow2_array,
                encoded_data,
                field,
                rlp_start_offset,
                tx_type,
                block_number,
            ),
            felt*,
        );
        invoke(func_ptr, 8, invoke_params);

        // Retrieve the results from [ap]
        let res_high = [ap - 1];
        let res_low = [ap - 2];
        let pow2_array = cast([ap - 3], felt*);
        let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
        let range_check_ptr = [ap - 5];

        // Process results and write to output
        let result = Uint256(low=res_low, high=res_high);
        if (as_be == 1) {
            let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
            assert output[0] = result.low;
            assert output[1] = result.high;

            return OutputType.UINT256;
        } else {
            assert output[0] = res_low;
            assert output[1] = res_high;

            return OutputType.UINT256;
        }
    }

    // Packs the evm decode params, depending on the dict_id.
    func pack_evm_decode_params{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        dict_id: felt, encoded_data: felt*, field: felt
    ) -> (invoke_params: felt*, param_len: felt) {
        if (dict_id == DictId.BLOCK_TX) {
            let (tx_type, rlp_start_offset) = EvmTransactionDecoder.open_tx_envelope(encoded_data);
            tempvar invoke_params = cast(
                new (
                    range_check_ptr,
                    bitwise_ptr,
                    pow2_array,
                    encoded_data,
                    field,
                    rlp_start_offset,
                    tx_type,
                ),
                felt*,
            );
            return (invoke_params=invoke_params, param_len=7);
        }

        tempvar invoke_params = cast(
            new (range_check_ptr, bitwise_ptr, pow2_array, encoded_data, field), felt*
        );
        return (invoke_params=invoke_params, param_len=5);
    }

    func pack_sn_decode_params{range_check_ptr}(
        fields: felt*, field: felt
    ) -> (invoke_params: felt*, param_len: felt) {
        tempvar invoke_params = cast(
            new (range_check_ptr, fields, field), felt*
        );
        return (invoke_params=invoke_params, param_len=3);
    }
}

namespace BootloaderMemorizerAccess {
    // This function is the only accesspoint the bootloader can access the memorizers over.
    // It handles:
    // - reading the memorizer
    // - decoding the value
    // - writing the value + return type to the output
    func read_and_decode{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        dict_ptr: DictAccess*,
        pow2_array: felt*,
        memorizer_handler: felt***,
        decoder_handler: felt***,
    }(
        params: felt*, layout: felt, dict_id: felt, field: felt, output_ptr: felt*, as_be: felt
    ) -> felt {
        alloc_locals;
        let (encoded_data) = InternalMemorizerReader.read(layout, dict_id, params);

        local is_evm_receipt;
        %{ ids.is_evm_receipt = 1 if ids.layout == 0 & ids.dict_id == 4 else 0 %}

        if (is_evm_receipt == 1) {
            assert layout = Layout.EVM;
            assert dict_id = DictId.BLOCK_RECEIPT;
            let block_number = params[1];
            let output_type = InternalValueDecoder.decode_evm_receipt(
                encoded_data, field, block_number, output_ptr, as_be
            );
            return output_type;
        }

        let output_type = InternalValueDecoder.decode(
            layout, dict_id, encoded_data, field, output_ptr, as_be
        );
        return output_type;
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
