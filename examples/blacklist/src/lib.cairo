#[starknet::contract]
mod module {
    use alexandria_bytes::{Bytes, BytesTrait};
    use alexandria_encoding::sol_abi::{decode::SolAbiDecodeTrait};
    use core::byte_array::ByteArrayImpl;
    use core::starknet::EthAddress;
    use hdp_cairo::{
        HDP, evm::ETHEREUM_TESTNET_CHAIN_ID,
        evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
        evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait},
        evm::log::{LogImpl, LogKey, LogTrait},
    };

    pub mod bloom;

    #[derive(Drop, Serde)]
    struct TxId {
        block_number: felt252,
        index: felt252,
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState, hdp: HDP, forbidden_address: EthAddress, txs: Array<TxId>,
    ) -> Array<felt252> {
        let mut res = array![];

        for tx in txs {
            let contract_address: EthAddress = hdp
                .evm
                .block_tx_get_receiver(
                    @BlockTxKey {
                        chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                        block_number: tx.block_number,
                        transaction_index: tx.index,
                    },
                )
                .try_into()
                .unwrap();
            assert!(contract_address == forbidden_address);

            if (bloom::contains(
                hdp
                    .evm
                    .block_receipt_get_bloom(
                        @BlockReceiptKey {
                            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                            block_number: tx.block_number,
                            transaction_index: tx.index,
                        },
                    ),
                u256 {
                    low: 0xda81b5164dd6d62b2eaf1e8bc6c34931,
                    high: 0xe9e508bad6d4c3227e881ca19068f099,
                },
            ) == true) {
                let key = LogKey {
                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                    block_number: tx.block_number,
                    transaction_index: tx.index,
                    log_index: 0,
                };

                let data = hdp.evm.log_get_data(@key);
                let encoded: Bytes = BytesTrait::new(data.len() * 0x20, data);

                let mut offset = 0;
                let address: EthAddress = encoded.decode(ref offset);

                println!("{:x}", address);
                res.append(address.into());
            }
        };

        res
    }
}
