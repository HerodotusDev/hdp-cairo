from packages.eth_essentials.lib.rlp_little import extract_byte_at_pos
from src.decoders.evm.receipt_decoder import ReceiptDecoder
from src.utils.chain_info import ChainInfo
from src.utils.chain_info import fetch_chain_info
from src.utils.rlp import rlp_list_retrieve, le_chunks_to_be_uint256, get_rlp_list_meta, get_rlp_len, decode_rlp_word_to_uint256
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.uint256 import Uint256

const LOGS_OFFSET = 3;

struct LogKey {
    chain_id: felt,
    block_number: felt,
    transaction_index: felt,
    log_index: felt,
}

namespace LogField {
    const ADDRESS = 0;
    const TOPIC0 = 1;
    const TOPIC1 = 2;
    const TOPIC2 = 3;
    const TOPIC3 = 4;
    const TOPIC4 = 5;
    const DATA = 6;
}

namespace LogFieldOffset {
    const LOG_ADDRESS_OFFSET = 0;
    const LOG_TOPICS_OFFSET = 1;
    const LOG_DATA_OFFSET = 2;
}

namespace LogDecoder {
    func get_field{keccak_ptr: KeccakBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
        rlp: felt*,
        field: felt,
        key: LogKey*
    ) -> (res_array: felt*, res_len: felt) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        let (tx_type, rlp_start_offset) = ReceiptDecoder.open_receipt_envelope(rlp);
        let (local value_start_offset) = get_rlp_list_meta(rlp, rlp_start_offset);

        if (field == LogField.ADDRESS) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_ADDRESS_OFFSET, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.TOPIC0) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_TOPICS_OFFSET, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogField.TOPIC0 - 1, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.TOPIC1) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_TOPICS_OFFSET, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogField.TOPIC1 - 1, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.TOPIC2) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_TOPICS_OFFSET, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogField.TOPIC2 - 1, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.TOPIC3) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_TOPICS_OFFSET, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogField.TOPIC3 - 1, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.TOPIC4) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_TOPICS_OFFSET, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogField.TOPIC4 - 1, 0, 0);
            let (local result) = le_chunks_to_be_uint256(res, res_len, bytes_len);
            return (res_array=&result, res_len=2);
        }

        if (field == LogField.DATA) {
            let (res, res_len, bytes_len) = rlp_list_retrieve(rlp, LOGS_OFFSET, value_start_offset, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, key.log_index, 0, 0);
            let (res, res_len, bytes_len) = rlp_list_retrieve(res, LogFieldOffset.LOG_DATA_OFFSET, 0, 0);
            
            let (local res_array: felt*) = alloc();
            abi_data_to_uint256_array(res, res_len, bytes_len, res_array);
            
            return (res_array=res_array, res_len=bytes_len / 0x20 * 2);
        }


        let (local res_array: felt*) = alloc();
        return (res_array=res_array, res_len=0);
    }

    func abi_data_to_uint256_array{keccak_ptr: KeccakBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(res: felt*, res_len: felt, bytes_len: felt, res_array: felt*) {
        alloc_locals;

        if (bytes_len == 0) {
            return ();
        }

        let (local result) = le_chunks_to_be_uint256(res, 4, 0x20);
        assert [res_array + 1] = result.low;
        assert [res_array + 0] = result.high;
        
        return abi_data_to_uint256_array(res + 4, res_len - 4, bytes_len - 0x20, res_array + 2);
    }
}
