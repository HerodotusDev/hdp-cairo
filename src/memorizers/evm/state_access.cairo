from src.decoders.evm.account_decoder import AccountDecoder as EvmAccountDecoder
from src.decoders.evm.header_decoder import HeaderDecoder as EvmHeaderDecoder
from src.decoders.evm.log_decoder import LogDecoder as EvmLogDecoder
from src.decoders.evm.receipt_decoder import ReceiptDecoder as EvmReceiptDecoder
from src.decoders.evm.storage_slot_decoder import StorageSlotDecoder as EvmStorageSlotDecoder
from src.decoders.evm.transaction_decoder import TransactionDecoder as EvmTransactionDecoder
from src.decoders.evm.code_decoder import CodeDecoder as EvmCodeDecoder
from src.memorizers.evm.memorizer import EvmMemorizer, EvmHashParams2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.registers import get_label_location
from starkware.cairo.common.uint256 import uint256_reverse_endian, Uint256

from src.utils.chain_info import Layout
from src.memorizers.bare import BareMemorizer

namespace EvmStateAccessType {
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const BLOCK_TX = 3;
    const BLOCK_RECEIPT = 4;

    const LOG = 5;
    const CODE = 6;
}

namespace EvmDecoder {
    func init() -> felt** {
        let (handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderDecoder.get_field);
        let (account_label) = get_label_location(EvmAccountDecoder.get_field);
        let (storage_label) = get_label_location(EvmStorageSlotDecoder.get_word);
        let (tx_label) = get_label_location(EvmTransactionDecoder.get_field);
        let (receipt_label) = get_label_location(EvmReceiptDecoder.get_field);
        let (log_label) = get_label_location(EvmLogDecoder.get_field);
        let (code_label) = get_label_location(EvmCodeDecoder.decode);

        assert handlers[EvmStateAccessType.HEADER] = header_label;


        assert handlers[EvmStateAccessType.ACCOUNT] = account_label;
        assert handlers[EvmStateAccessType.STORAGE] = storage_label;
        assert handlers[EvmStateAccessType.BLOCK_TX] = tx_label;
        assert handlers[EvmStateAccessType.BLOCK_RECEIPT] = receipt_label;

        assert handlers[EvmStateAccessType.LOG] = log_label;
        assert handlers[EvmStateAccessType.CODE] = code_label;

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
        keccak_ptr: felt*,
    }(rlp: felt*, params: felt*, state_access_type: felt, field: felt) -> (len: felt) {
        alloc_locals;

        let func_ptr = evm_decoder_ptr[state_access_type];

        // All decoders have the same signature:
        // {implicits: 4}(args: 3) -> (implicits: 4, returns: 2)
        // Implicits: keccak_ptr, range_check_ptr, bitwise_ptr, pow2_array
        // Args: rlp, field, key_ptr (params)
        // Returns: res_array, res_len

        let (
            new_keccak, 
            new_range, 
            new_bitwise, 
            new_pow2, 
            res_array: felt*, 
            res_len
        ) = call_decoder(
            cast(func_ptr, felt), 
            cast(keccak_ptr, felt), 
            range_check_ptr, 
            cast(bitwise_ptr, felt), 
            cast(pow2_array, felt), 
            cast(rlp, felt), 
            field, 
            cast(params, felt)
        );

        // Update implicits
        let keccak_ptr = cast(new_keccak, felt*);
        let range_check_ptr = new_range;
        let bitwise_ptr = cast(new_bitwise, BitwiseBuiltin*);
        let pow2_array = cast(new_pow2, felt*);

        // Copy result to output_ptr
        memcpy(dst=output_ptr, src=res_array, len=res_len);

        return (len=res_len);
    }
}

// Helper to call decoders with 4 implicits and 3 arguments, returning 4 implicits and 2 results
func call_decoder(
    func_ptr: felt, 
    imp1: felt, imp2: felt, imp3: felt, imp4: felt,
    arg1: felt, arg2: felt, arg3: felt
) -> (r1: felt, r2: felt, r3: felt, r4: felt, r5: felt, r6: felt) {
    [ap] = imp1, ap++;
    [ap] = imp2, ap++;
    [ap] = imp3, ap++;
    [ap] = imp4, ap++;
    [ap] = arg1, ap++;
    [ap] = arg2, ap++;
    [ap] = arg3, ap++;
    call abs func_ptr;
    return (r1=[ap-6], r2=[ap-5], r3=[ap-4], r4=[ap-3], r5=[ap-2], r6=[ap-1]);
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
        let (log_label) = get_label_location(EvmHashParams2.log);
        let (code_label) = get_label_location(EvmHashParams2.code);

        assert evm_key_hasher_ptr[EvmStateAccessType.HEADER] = header_label;


        assert evm_key_hasher_ptr[EvmStateAccessType.ACCOUNT] = account_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.STORAGE] = storage_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.BLOCK_TX] = tx_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.BLOCK_RECEIPT] = receipt_label;

        assert evm_key_hasher_ptr[EvmStateAccessType.LOG] = log_label;
        assert evm_key_hasher_ptr[EvmStateAccessType.CODE] = code_label;

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
        keccak_ptr: felt*,
        evm_memorizer: DictAccess*,
        evm_decoder_ptr: felt**,
        evm_key_hasher_ptr: felt**,
        pow2_array: felt*,
        output_ptr: felt*,
    }(params: felt*, state_access_type: felt, field: felt) -> (len: felt) {
        alloc_locals;  // ToDo: currently needed to retrieve the poseidon_ptr from the compute_memorizer_key call. Find way to remove this

        let (memorizer_key) = compute_memorizer_key(params, state_access_type);
        let (rlp) = EvmMemorizer.get(memorizer_key);

        if (cast(rlp, felt) == BareMemorizer.DEFAULT_VALUE) {
            return (len=0);
        }

        let (res_len) = EvmDecoder.decode(rlp, params, state_access_type, field);

        return (len=res_len);
    }

    // Computes the memorizer key by invoking the corresponding key hasher
    // Returns:
    // - The memorizer key
    func compute_memorizer_key{poseidon_ptr: PoseidonBuiltin*, evm_key_hasher_ptr: felt**}(
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

// The reader maps this function to memorizers that are not available in a specific memorizer layout
func invalid_memorizer_access{dict_ptr: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(
    params: felt*
) {
    with_attr error_message("INVALID MEMORIZER ACCESS") {
        assert 1 = 0;
    }

    return ();
}
