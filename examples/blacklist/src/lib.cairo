#[starknet::contract]
mod module {
    use alexandria_bytes::{Bytes, BytesTrait};
    use alexandria_encoding::sol_abi::{decode::SolAbiDecodeTrait};
    use core::byte_array::ByteArrayImpl;
    use core::num::traits::BitSize;
    use core::starknet::EthAddress;
    use hdp_cairo::{
        HDP, evm::ETHEREUM_TESTNET_CHAIN_ID,
        evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
        evm::block_tx::{BlockTxImpl, BlockTxKey, BlockTxTrait},
        evm::header::{HeaderImpl, HeaderKey, HeaderTrait}, evm::log::{LogImpl, LogKey, LogTrait},
    };

    const MAX_CONSIDERED_LOGS_PER_TRANSACTION: u32 = 80000;

    const WITHDRAWAL_EVENT_SIGNATURE: u256 = u256 {
        // Event signature Withdrawal (address to, bytes32 nullifierHash, index_topic_1
        // address relayer, uint256 fee)View Source
        // https://sepolia.etherscan.io/tx/0x2cdbdae6c1ebd5f8502531c5a130d5d603662cdb7874ab7ca2494b6c7ec5144e#eventlog
        low: 0xda81b5164dd6d62b2eaf1e8bc6c34931, high: 0xe9e508bad6d4c3227e881ca19068f099,
    };

    pub mod bloom;

    #[derive(Drop, Serde)]
    struct BlockId {
        block_number: u32,
        tx_count: u32,
    }

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(
        ref self: ContractState, hdp: HDP, forbidden_address: EthAddress, blocks: Array<BlockId>,
    ) -> Array<felt252> {
        let mut res = array![forbidden_address.into()];

        for block in blocks {
            res.append(block.block_number.into());
            res.append(block.tx_count.into());

            if (bloom::contains(
                hdp
                    .evm
                    .header_get_bloom(
                        @HeaderKey {
                            chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                            block_number: block.block_number.into(),
                        },
                    ),
                WITHDRAWAL_EVENT_SIGNATURE,
            ) == true) {
                for index in 0..block.tx_count {
                    // Check if the bloom filter in the block receipt contains the specific target
                    // value corresponding to Withdrawal (address to, bytes32 nullifierHash,
                    // index_topic_1 address relayer, uint256 fee) event of
                    // https://sepolia.etherscan.io/address/0x1572afe6949fdf51cb3e0856216670ae9ee160ee
                    // contract.
                    if (bloom::contains(
                        hdp
                            .evm
                            .block_receipt_get_bloom(
                                @BlockReceiptKey {
                                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                                    block_number: block.block_number.into(),
                                    transaction_index: index.into(),
                                },
                            ),
                        WITHDRAWAL_EVENT_SIGNATURE,
                    ) == true) {
                        // Get the contract address (receiver) for the transaction.
                        let contract_address: EthAddress = hdp
                            .evm
                            .block_tx_get_receiver(
                                @BlockTxKey {
                                    chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                                    block_number: block.block_number.into(),
                                    transaction_index: index.into(),
                                },
                            )
                            .try_into()
                            .unwrap();
                        // Assert that the receiver address matches the forbidden address.
                        assert!(contract_address == forbidden_address);

                        let mut counter: u32 = 0;
                        while counter < MAX_CONSIDERED_LOGS_PER_TRANSACTION {
                            // Create a key to access the log of the transaction.
                            let key = LogKey {
                                chain_id: ETHEREUM_TESTNET_CHAIN_ID,
                                block_number: block.block_number.into(),
                                transaction_index: index.into(),
                                log_index: counter.into(),
                            };

                            let topic0 = hdp.evm.log_get_topic0(@key);
                            if (topic0 == WITHDRAWAL_EVENT_SIGNATURE) {
                                // Retrieve the log data.
                                let data = hdp.evm.log_get_data(@key);
                                let encoded: Bytes = BytesTrait::new(
                                    data.len() * BitSize::<u256>::bits() / BitSize::<u8>::bits(),
                                    data,
                                );

                                let mut offset = 0;
                                // Decode the data to extract an Ethereum address corresponding to
                                // Withdrawal (address: to) field.
                                let address: EthAddress = encoded.decode(ref offset);
                                res.append(address.into());
                                break;
                            }

                            counter += 1;
                        }
                    }
                };
            }
        };

        res
    }
}
