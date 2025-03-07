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
            // Get the contract address (receiver) for the transaction.
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
            // Assert that the receiver address matches the forbidden address.
            assert!(contract_address == forbidden_address);

            // Check if the bloom filter in the block receipt contains the specific target value coresponding to 
            // Withdrawal (address to, bytes32 nullifierHash, index_topic_1 address relayer, uint256 fee) event of 
            // https://sepolia.etherscan.io/address/0x1572afe6949fdf51cb3e0856216670ae9ee160ee contract.
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
                // Create a key to access the first log of the transaction.
                let key = LogKey {
                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                    block_number: tx.block_number,
                    transaction_index: tx.index,
                    log_index: 0,
                };

                // Retrieve the log data.
                let data = hdp.evm.log_get_data(@key);
                let encoded: Bytes = BytesTrait::new(data.len() * 0x20, data);

                let mut offset = 0;
                // Decode the data to extract an Ethereum address corresponding to Withdrawal (address: to) field.
                let address: EthAddress = encoded.decode(ref offset);

                println!("{:x}", address);
                res.append(address.into());
            }
        };

        // Return the array of blacklisted addresses.
        res
    }
}
