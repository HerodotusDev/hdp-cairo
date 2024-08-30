from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from src.memorizers.evm import EvmHeaderMemorizer, EvmAccountMemorizer, EvmStorageMemorizer, EvmBlockTxMemorizer, EvmBlockReceiptMemorizer
from src.memorizers.starknet import StarknetHeaderMemorizer
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin

namespace MemorizerId { 
    const HEADER = 0;
    const ACCOUNT = 1;
    const STORAGE = 2;
    const BLOCK_TX = 3;
    const BLOCK_RECEIPT = 4;
}

namespace StarknetLayout {
    const Header = 0;
}

namespace MemorizerLayout {
    const EVM = 0;
    const STARKNET = 1;
}

namespace MemorizerReader {
    func init() -> felt*** {
        let (evm_handlers: felt**) = alloc();
        let (header_label) = get_label_location(EvmHeaderMemorizer.get);
        let (account_label) = get_label_location(EvmAccountMemorizer.get);
        let (storage_label) = get_label_location(EvmStorageMemorizer.get);
        let (block_tx_label) = get_label_location(EvmBlockTxMemorizer.get);
        let (block_receipt_label) = get_label_location(EvmBlockReceiptMemorizer.get);

        assert evm_handlers[MemorizerId.HEADER] = header_label;
        assert evm_handlers[MemorizerId.ACCOUNT] = account_label;
        assert evm_handlers[MemorizerId.STORAGE] = storage_label;
        assert evm_handlers[MemorizerId.BLOCK_TX] = block_tx_label;
        assert evm_handlers[MemorizerId.BLOCK_RECEIPT] = block_receipt_label;

        let (sn_handlers: felt**) = alloc();
        let (header_label) = get_label_location(StarknetHeaderMemorizer.get);
        assert sn_handlers[StarknetLayout.Header] = header_label;

        let (handlers: felt***) = alloc();
        assert handlers[MemorizerLayout.EVM] = evm_handlers;
        assert handlers[MemorizerLayout.STARKNET] = sn_handlers;

        return handlers;
    }

    func read{
        dict_ptr: DictAccess*,
        poseidon_ptr: PoseidonBuiltin*,
        memorizer_handler: felt***,
    }(memorizer_layout: felt, memorizer_id: felt, params: felt*) -> (res: felt*) {
        let func_ptr = memorizer_handler[memorizer_layout][memorizer_id];

        tempvar invoke_params = cast(new(dict_ptr, poseidon_ptr, params), felt*);
        invoke(func_ptr, 3, invoke_params);
                
        let res = cast([ap - 1], felt*);
        let poseidon_ptr = cast([ap - 2], PoseidonBuiltin*);
        let dict_ptr = cast([ap - 3], DictAccess*);

        return (res=res);
    }

}

// The reader maps this function to memorizers that are not available in a specific memorizer layout
func invalid_memorizer_access{
    dict_ptr: DictAccess*,
    poseidon_ptr: PoseidonBuiltin*,
}(params: felt*) {
    with_attr error_message("INVALID MEMORIZER ACCESS") {
        assert 1 = 0;
    }
}