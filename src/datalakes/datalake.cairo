from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin
from starkware.cairo.common.registers import get_fp_and_pc, get_label_location
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from src.datalakes.block_sampled_datalake import (
    init_block_sampled,
    fetch_data_points as fetch_block_sampled_data_points,
)
from src.datalakes.txs_in_block_datalake import (
    init_txs_in_block,
    fetch_data_points as fetch_txs_in_block_data_points,
)

from src.types import (
    ComputationalTask,
    BlockSampledDataLake,
    TransactionsInBlockDatalake,
    ChainInfo,
)
from src.datalakes.block_sampled_datalake import (
    fetch_header_data_points,
    fetch_account_data_points,
    fetch_storage_data_points,
)
from src.datalakes.txs_in_block_datalake import fetch_tx_data_points, fetch_receipt_data_points
from src.tasks.fetch_trait import (
    FetchTrait,
    FetchTraitBlockSampledDatalake,
    FetchTraitTransactionDatalake,
)

namespace DatalakeType {
    const BLOCK_SAMPLED = 0;
    const TXS_IN_BLOCK = 1;
}

namespace Datalake {
    func init{
        range_check_ptr, bitwise_ptr: BitwiseBuiltin*, keccak_ptr: KeccakBuiltin*, pow2_array: felt*
    }(input: felt*, input_bytes_len: felt, type: felt) -> (datalake_ptr: felt*) {
        alloc_locals;
        let (__fp__, _) = get_fp_and_pc();

        if (type == 0) {
            let (local block_sampled) = init_block_sampled(input, input_bytes_len);
            let datalake_ptr: felt* = cast(&block_sampled, felt*);
            return (datalake_ptr=datalake_ptr);
        }

        if (type == 1) {
            let (local txs_in_block) = init_txs_in_block(input, input_bytes_len);
            let datalake_ptr: felt* = cast(&txs_in_block, felt*);
            return (datalake_ptr=datalake_ptr);
        }

        assert 1 = 0;

        let (res) = alloc();
        return (datalake_ptr=res);
    }

    // Collects the data points for BlocKSampledDataLakes
    func fetch_data_points{
        range_check_ptr,
        poseidon_ptr: PoseidonBuiltin*,
        bitwise_ptr: BitwiseBuiltin*,
        account_dict: DictAccess*,
        storage_dict: DictAccess*,
        header_dict: DictAccess*,
        block_tx_dict: DictAccess*,
        block_receipt_dict: DictAccess*,
        pow2_array: felt*,
        fetch_trait: FetchTrait,
        chain_info: ChainInfo,
    }(task: ComputationalTask) -> (res: Uint256*, res_len: felt) {
        if (task.datalake_type == DatalakeType.BLOCK_SAMPLED) {
            let block_sampled_datalake: BlockSampledDataLake = [
                cast(task.datalake_ptr, BlockSampledDataLake*)
            ];
            let (res, res_len) = fetch_block_sampled_data_points(
                task.chain_id, block_sampled_datalake
            );

            return (res=res, res_len=res_len);
        }

        if (task.datalake_type == DatalakeType.TXS_IN_BLOCK) {
            let tx_in_block_datalake: TransactionsInBlockDatalake = [
                cast(task.datalake_ptr, TransactionsInBlockDatalake*)
            ];
            let (res, res_len) = fetch_txs_in_block_data_points(
                task.chain_id, tx_in_block_datalake
            );

            return (res=res, res_len=res_len);
        }

        assert 1 = 0;
        let (res: Uint256*) = alloc();
        return (res=res, res_len=0);
    }
}

func get_default_fetch_trait() -> FetchTrait {
    alloc_locals;
    let (__fp__, _) = get_fp_and_pc();

    let (fetch_header_data_points_ptr) = get_label_location(fetch_header_data_points);
    let (fetch_account_data_points_ptr) = get_label_location(fetch_account_data_points);
    let (fetch_storage_data_points_ptr) = get_label_location(fetch_storage_data_points);
    let (fetch_tx_data_points_ptr) = get_label_location(fetch_tx_data_points);
    let (fetch_receipt_data_points_ptr) = get_label_location(fetch_receipt_data_points);

    local block_sampled_datalake: FetchTraitBlockSampledDatalake = FetchTraitBlockSampledDatalake(
        fetch_header_data_points_ptr, fetch_account_data_points_ptr, fetch_storage_data_points_ptr
    );

    local transaction_datalake: FetchTraitTransactionDatalake = FetchTraitTransactionDatalake(
        fetch_tx_data_points_ptr, fetch_receipt_data_points_ptr
    );

    return (
        FetchTrait(
            block_sampled_datalake=&block_sampled_datalake,
            transaction_datalake=&transaction_datalake,
        )
    );
}
