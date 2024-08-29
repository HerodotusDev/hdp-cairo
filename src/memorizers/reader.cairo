from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_label_location
from src.memorizers.evm import EvmHeaderMemorizer, EvmAccountMemorizer, EvmStorageMemorizer, EvmBlockTxMemorizer, EvmBlockReceiptMemorizer
from src.memorizers.starknet import StarknetHeaderMemorizer
from starkware.cairo.common.invoke import invoke
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin


// ToDo: rename
namespace EvmLayout { 
    const Header = 0;
    const Header2 = 1;
    const Account = 2;
    const Account2 = 3;
    const Storage = 4;
    const Storage2 = 5;
    const BlockTx = 6;
    const BlockTx2 = 7;
    const BlockReceipt = 8;
    const BlockReceipt2 = 9;    
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
        let (header2_label) = get_label_location(EvmHeaderMemorizer.get2);
        let (account_label) = get_label_location(EvmAccountMemorizer.get);
        let (account2_label) = get_label_location(EvmAccountMemorizer.get2);
        let (storage_label) = get_label_location(EvmStorageMemorizer.get);
        let (storage2_label) = get_label_location(EvmStorageMemorizer.get2);
        let (block_tx_label) = get_label_location(EvmBlockTxMemorizer.get);
        let (block_tx2_label) = get_label_location(EvmBlockTxMemorizer.get2);
        let (block_receipt_label) = get_label_location(EvmBlockReceiptMemorizer.get);
        let (block_receipt2_label) = get_label_location(EvmBlockReceiptMemorizer.get2);

        assert evm_handlers[EvmLayout.Header] = header_label;
        assert evm_handlers[EvmLayout.Header2] = header2_label;
        assert evm_handlers[EvmLayout.Account] = account_label;
        assert evm_handlers[EvmLayout.Account2] = account2_label;
        assert evm_handlers[EvmLayout.Storage] = storage_label;
        assert evm_handlers[EvmLayout.Storage2] = storage2_label;
        assert evm_handlers[EvmLayout.BlockTx] = block_tx_label;
        assert evm_handlers[EvmLayout.BlockTx2] = block_tx2_label;
        assert evm_handlers[EvmLayout.BlockReceipt] = block_receipt_label;
        assert evm_handlers[EvmLayout.BlockReceipt2] = block_receipt2_label;

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
    }(memorizer_layout: felt, memorizer_id: felt, params: felt*) -> (res: felt*, res_len: felt) {
        let func_ptr = memorizer_handler[memorizer_layout][memorizer_id];

        tempvar invoke_params = cast(new(dict_ptr, poseidon_ptr, params), felt*);
        invoke(func_ptr, 3, invoke_params);
                
        let res_len = [ap - 1];
        let res = cast([ap - 2], felt*);
        let poseidon_ptr = cast([ap - 3], PoseidonBuiltin*);
        let dict_ptr = cast([ap - 4], DictAccess*);

        return (res=res, res_len=res_len);
    }
}
