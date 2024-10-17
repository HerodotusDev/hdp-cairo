%builtins range_check bitwise keccak poseidon

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian
from starkware.cairo.common.dict_access import DictAccess

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, PoseidonBuiltin, KeccakBuiltin
from src.decoders.evm.header_decoder import HeaderDecoder, HeaderField
from packages.eth_essentials.lib.utils import pow2alloc128
from tests.utils.header import test_header_decoding
from src.memorizers.evm.memorizer import (
    EvmHeaderMemorizer,
    EvmAccountMemorizer,
    EvmStorageMemorizer,
    EvmBlockTxMemorizer,
    EvmBlockReceiptMemorizer,
)
from src.memorizer_access import (
    BootloaderMemorizerAccess,
    InternalMemorizerReader,
    InternalValueDecoder,
    DictId,
)
from src.chain_info import Layout

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*,
    keccak_ptr: KeccakBuiltin*,
    poseidon_ptr: PoseidonBuiltin*,
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    return ();
}

func test_bootloader_access{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    memorizer_handler: felt***,
    decoder_handler: felt***,
}() {
    alloc_locals;

    let (evm_header_dict, evm_header_dict_start) = EvmHeaderMemorizer.init();
    let (evm_account_dict, evm_account_dict_start) = EvmAccountMemorizer.init();
    let (evm_storage_dict, evm_storage_dict_start) = EvmStorageMemorizer.init();
    let (evm_block_tx_dict, evm_block_tx_dict_start) = EvmBlockTxMemorizer.init();
    let (evm_block_receipt_dict, evm_block_receipt_dict_start) = EvmBlockReceiptMemorizer.init();
    // let (starknet_header_dict, starknet_header_dict_start) = StarknetHeaderMemorizer.init();

    let memorizer_handler = InternalMemorizerReader.init();
    let decoder_handler = InternalValueDecoder.init();

    return ();
}

func test_evm_header_access{
    range_check_ptr,
    poseidon_ptr: PoseidonBuiltin*,
    bitwise_ptr: BitwiseBuiltin*,
    pow2_array: felt*,
    memorizer_handler: felt***,
    decoder_handler: felt***,
    evm_header_dict: DictAccess*,
}() {
    alloc_locals;
    local block_number = 124358;
    let (evm_header: felt*) = alloc();
    %{
        from tests.python.test_header_decoding import fetch_evm_header_dict
        header = fetch_evm_header_dict(ids.block_number)
        print("Running Block #", block_numbers[ids.index])
        segments.write_arg(ids.evm_header, header['rlp'])
    %}
    // Write header to memorizer
    EvmHeaderMemorizer.add(11155111, block_number, evm_header);

    let (output_ptr: felt*) = alloc();
    let dict_ptr = evm_header_dict;
    with dict_ptr {
        // test bootloader access
        let type = BootloaderMemorizerAccess.read_and_decode(
            new (11155111, block_number, 0),
            Layout.EVM,
            DictId.HEADER,
            HeaderField.PARENT,
            output_ptr,
            1,
        );
    }

    let value = InternalValueDecoder.decode2(
        Layout.EVM, DictId.HEADER, evm_header, HeaderField.PARENT, 1
    );

    %{
        assert memory[ids.output_ptr] == header['parent_hash']['high']
        assert memory[ids.output_ptr + 1] == header['parent_hash']['low']
        assert memory[ids.value] == header['parent_hash']['high']
        assert memory[ids.value + 1] == header['parent_hash']['low']
    %}

    return ();
}
