from src.decoders.evm.header_decoder import HeaderDecoder as EvmHeaderDecoder
from src.decoders.evm.account_decoder import AccountDecoder as EvmAccountDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder as EvmStorageSlotDecoder
from src.decoders.evm.transaction_decoder import TransactionDecoder as EvmTransactionDecoder
from src.decoders.evm.receipt_decoder import ReceiptDecoder as EvmReceiptDecoder
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.invoke import invoke

namespace DecoderId {
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const TX = 3;
    const RECEIPT = 4;
}

namespace DecoderLayout {
    const EVM = 0;
    const STARKNET = 1;
}

namespace ValueDecoder {
    func init() -> felt*** {
        let (evm_handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderDecoder.get_field);
        let (account_label) = get_label_location(EvmAccountDecoder.get_field);
        let (storage_label) = get_label_location(EvmStorageSlotDecoder.get_word);
        let (tx_label) = get_label_location(EvmTransactionDecoder.get_field);
        let (receipt_label) = get_label_location(EvmReceiptDecoder.get_field);

        assert evm_handlers[DecoderId.HEADER] = header_label;
        assert evm_handlers[DecoderId.ACCOUNT] = account_label;
        assert evm_handlers[DecoderId.STORAGE] = storage_label;
        // assert evm_handlers[DecoderId.TX] = tx_label;
        // assert evm_handlers[DecoderId.RECEIPT] = receipt_label;

        let (handlers: felt***) = alloc();
        assert handlers[DecoderLayout.EVM] = evm_handlers;

        return handlers;
    }

    func decode{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, decoder_handler: felt***
    }(
        decoder_layout: felt,
        decoder_id: felt,
        value: felt*,
        field: felt,
        to_be: felt,
        output: felt*,
    ) {
        let func_ptr = decoder_handler[decoder_layout][decoder_id];

        // Invoke the decoder function
        tempvar invoke_params = cast(
            new (range_check_ptr, bitwise_ptr, pow2_array, value, field), felt*
        );
        invoke(func_ptr, 5, invoke_params);

        // Retrieve the results from [ap]
        let res_low = [ap - 1];
        let res_high = [ap - 2];

        // pow2_array is static, so we can skip it
        let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
        let range_check_ptr = [ap - 5];

        // Process results and write to output
        if (decoder_layout == DecoderLayout.EVM) {
            if (to_be == 1) {
                let (result) = uint256_reverse_endian(Uint256(low=res_low, high=res_high));
                assert output[0] = result.high;
                assert output[1] = result.low;

                return ();
            } else {
                assert output[0] = res_high;
                assert output[1] = res_low;

                return ();
            }
        } else {
            // ToDo: We need to decide how to handle starknet words internally.
            // This is a larger discussion, as it has many implications.
            with_attr error_message("STARKNET DECODER NOT IMPLEMENTED") {
                assert 1 = 0;
            }
        }

        return ();
    }

    func decode2{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*, decoder_handler: felt***
    }(decoder_layout: felt, decoder_id: felt, value: felt*, field: felt, to_be: felt) -> Uint256 {
        let func_ptr = decoder_handler[decoder_layout][decoder_id];

        // Invoke the decoder function
        tempvar invoke_params = cast(
            new (range_check_ptr, bitwise_ptr, pow2_array, value, field), felt*
        );
        invoke(func_ptr, 5, invoke_params);

        // Retrieve the results from [ap]
        let res_high = [ap - 1];
        let res_low = [ap - 2];

        // pow2_array is static, so we can skip it
        let bitwise_ptr = cast([ap - 4], BitwiseBuiltin*);
        let range_check_ptr = [ap - 5];

        // Process results and write to output
        if (decoder_layout == DecoderLayout.EVM) {
            let result = Uint256(low=res_low, high=res_high);
            if (to_be == 1) {
                let (be_result) = uint256_reverse_endian(num=result);
                return be_result;
            } else {
                return result;
            }
        } else {
            with_attr error_message("STARKNET DECODER NOT IMPLEMENTED") {
                assert 1 = 0;
            }
        }
        return (Uint256(low=0, high=0));
    }
}
