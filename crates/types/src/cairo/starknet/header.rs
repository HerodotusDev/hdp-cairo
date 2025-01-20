use cairo_vm::Felt252;
pub use pathfinder_gateway_types::reply::Block;
use pathfinder_gateway_types::reply::L1DataAvailabilityMode;
use serde::{Deserialize, Serialize};
use strum_macros::FromRepr;
use version_compare::{CompOp, Version};

use crate::cairo::structs::Felt;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    BlockNumber = 0,
    StateRoot = 1,
    SequencerAddress = 2,
    BlockTimestamp = 3,
    TransactionCount = 4,
    TransactionCommitment = 5,
    EventCount = 6,
    EventCommitment = 7,
    Parent = 8,
    StateDiffCommitment = 9,
    StateDiffLength = 10,
    L1GasPriceWei = 11,
    L1GasPriceFri = 12,
    L1DataGasPriceWei = 13,
    L1DataGasPriceFri = 14,
    ReceiptCommitment = 15,
    Version = 16,
}

impl From<Block> for StarknetBlock {
    fn from(value: Block) -> Self {
        let binding = value.starknet_version.to_string();
        let version = Version::from(&binding).unwrap();
        match version.compare(&Version::from("0.13.2").unwrap()) {
            CompOp::Gt | CompOp::Eq => StarknetBlock::V0_13_2(StarknetBlock0_13_2::from_block(&value)),
            _ => StarknetBlock::Legacy(StarknetBlockLegacy::from_block(&value)),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum StarknetBlock {
    Legacy(StarknetBlockLegacy),
    V0_13_2(StarknetBlock0_13_2),
}

impl StarknetBlock {
    pub fn n_fields(&self) -> usize {
        match self {
            StarknetBlock::Legacy(_) => StarknetBlockLegacy::n_fields(),
            StarknetBlock::V0_13_2(_) => StarknetBlock0_13_2::n_fields(),
        }
    }

    pub fn n_fields_from_first_word(first_word: Felt252) -> usize {
        // 0x535441524b4e45545f424c4f434b5f4841534830 = int.from_bytes(b"STARKNET_BLOCK_HASH0", "big"),
        if first_word == Felt252::from_hex("0x535441524b4e45545f424c4f434b5f4841534830").unwrap() {
            StarknetBlock0_13_2::n_fields()
        } else {
            StarknetBlockLegacy::n_fields()
        }
    }

    pub fn from_fields(fields: Vec<Felt252>) -> Self {
        match fields.len() {
            n if n == StarknetBlockLegacy::n_fields() => StarknetBlock::Legacy(StarknetBlockLegacy::from_fields(fields)),
            n if n == StarknetBlock0_13_2::n_fields() => StarknetBlock::V0_13_2(StarknetBlock0_13_2::from_fields(fields)),
            _ => panic!("Invalid number of fields"),
        }
    }

    pub fn from_hash_fields(fields: Vec<Felt252>) -> Self {
        match fields.len() {
            n if n == StarknetBlockLegacy::n_hash_fields() => StarknetBlock::Legacy(StarknetBlockLegacy::from_hash_fields(fields)),
            n if n == StarknetBlock0_13_2::n_hash_fields() => StarknetBlock::V0_13_2(StarknetBlock0_13_2::from_hash_fields(fields)),
            _ => panic!("Invalid number of fields"),
        }
    }

    pub fn parent_block_hash(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.parent_block_hash,
            StarknetBlock::V0_13_2(block) => block.parent_block_hash,
        }
    }

    pub fn block_number(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.block_number,
            StarknetBlock::V0_13_2(block) => block.block_number,
        }
    }

    pub fn state_root(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.state_root,
            StarknetBlock::V0_13_2(block) => block.state_root,
        }
    }

    pub fn sequencer_address(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.sequencer_address,
            StarknetBlock::V0_13_2(block) => block.sequencer_address,
        }
    }

    pub fn block_timestamp(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.block_timestamp,
            StarknetBlock::V0_13_2(block) => block.block_timestamp,
        }
    }

    pub fn transaction_count(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.transaction_count,
            StarknetBlock::V0_13_2(block) => {
                // In v0.13.2, transaction count is part of concatenated_counts
                // You might need to implement logic to extract it from concatenated_counts
                block.concatenated_counts // This might need adjustment based on how counts are concatenated
            }
        }
    }

    pub fn transaction_commitment(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.transaction_commitment,
            StarknetBlock::V0_13_2(block) => block.transaction_commitment,
        }
    }

    pub fn event_count(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.event_count,
            StarknetBlock::V0_13_2(block) => {
                // Similar to transaction_count, this might need to be extracted from concatenated_counts
                block.concatenated_counts // This might need adjustment
            }
        }
    }

    pub fn event_commitment(&self) -> Felt252 {
        match self {
            StarknetBlock::Legacy(block) => block.event_commitment,
            StarknetBlock::V0_13_2(block) => block.event_commitment,
        }
    }

    // V0.13.2 specific fields with Option return types
    pub fn l1_gas_price_wei(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.l1_gas_price_wei),
        }
    }

    pub fn l1_gas_price_fri(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.l1_gas_price_fri),
        }
    }

    pub fn l1_data_gas_price_wei(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.l1_data_gas_price_wei),
        }
    }

    pub fn l1_data_gas_price_fri(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.l1_data_gas_price_fri),
        }
    }

    pub fn state_diff_commitment(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.state_diff_commitment),
        }
    }

    pub fn state_diff_length(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.concatenated_counts),
        }
    }

    pub fn receipt_commitment(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.receipt_commitment),
        }
    }

    pub fn protocol_version(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.protocol_version),
        }
    }

    pub fn version(&self) -> Option<Felt252> {
        match self {
            StarknetBlock::Legacy(_) => None,
            StarknetBlock::V0_13_2(block) => Some(block.protocol_version),
        }
    }

    pub fn handle(&self, function_id: FunctionId) -> Felt {
        match function_id {
            FunctionId::Parent => self.parent_block_hash().into(),
            FunctionId::BlockNumber => self.block_number().into(),
            FunctionId::StateRoot => self.state_root().into(),
            FunctionId::SequencerAddress => self.sequencer_address().into(),
            FunctionId::BlockTimestamp => self.block_timestamp().into(),
            FunctionId::TransactionCount => self.transaction_count().into(),
            FunctionId::TransactionCommitment => self.transaction_commitment().into(),
            FunctionId::EventCount => self.event_count().into(),
            FunctionId::EventCommitment => self.event_commitment().into(),
            FunctionId::StateDiffCommitment => self.state_diff_commitment().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::StateDiffLength => self.state_diff_length().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::ReceiptCommitment => self.receipt_commitment().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::L1GasPriceWei => self.l1_gas_price_wei().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::L1GasPriceFri => self.l1_gas_price_fri().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::L1DataGasPriceWei => self.l1_data_gas_price_wei().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::L1DataGasPriceFri => self.l1_data_gas_price_fri().unwrap_or_else(|| Felt252::ZERO.into()).into(),
            FunctionId::Version => self.version().unwrap_or_else(|| Felt252::ZERO.into()).into(),
        }
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct StarknetBlockLegacy {
    pub block_number: Felt252,
    pub state_root: Felt252,
    pub sequencer_address: Felt252,
    pub block_timestamp: Felt252,
    pub transaction_count: Felt252,
    pub transaction_commitment: Felt252,
    pub event_count: Felt252,
    pub event_commitment: Felt252,
    pub parent_block_hash: Felt252,
}

impl StarknetBlockLegacy {
    pub fn from_fields(fields: Vec<Felt252>) -> Self {
        Self {
            block_number: fields[0],
            state_root: fields[1],
            sequencer_address: fields[2],
            block_timestamp: fields[3],
            transaction_count: fields[4],
            transaction_commitment: fields[5],
            event_count: fields[6],
            event_commitment: fields[7],
            parent_block_hash: fields[8],
        }
    }

    // We build the header from the indexer API
    pub fn from_hash_fields(fields: Vec<Felt252>) -> Self {
        Self {
            block_number: fields[0],
            state_root: fields[1],
            sequencer_address: fields[2],
            block_timestamp: fields[3],
            transaction_count: fields[4],
            transaction_commitment: fields[5],
            event_count: fields[6],
            event_commitment: fields[7], // There are two zeros here that are hashed
            parent_block_hash: fields[10],
        }
    }

    // We build the header from the feeder gateway
    pub fn from_block(block: &Block) -> Self {
        let total_events: usize = block.transaction_receipts.iter().map(|(_, events)| events.len()).sum();
        let total_transactions: usize = block.transactions.len();
        Self {
            block_number: Felt252::from(block.block_number.get()).into(),
            state_root: Felt252::from_bytes_be(&block.state_commitment.as_inner().to_be_bytes()).into(),
            sequencer_address: Felt252::from_bytes_be(&block.sequencer_address.ok_or(Felt252::ZERO).unwrap().as_inner().to_be_bytes()).into(),
            block_timestamp: Felt252::from(block.timestamp.get()).into(),
            transaction_count: Felt252::from(total_transactions).into(),
            transaction_commitment: Felt252::from_bytes_be(&block.transaction_commitment.as_inner().to_be_bytes()).into(),
            event_count: Felt252::from(total_events).into(),
            event_commitment: Felt252::from_bytes_be(&block.event_commitment.as_inner().to_be_bytes()).into(),
            parent_block_hash: Felt252::from_bytes_be(&block.parent_block_hash.as_inner().to_be_bytes()).into(),
        }
    }

    pub fn n_fields() -> usize {
        11
    }

    pub fn n_hash_fields() -> usize {
        11
    }

    pub fn to_hash_fields(&self) -> Vec<Felt252> {
        vec![
            self.block_number,
            self.state_root,
            self.sequencer_address,
            self.block_timestamp,
            self.transaction_count,
            self.transaction_commitment,
            self.event_count,
            self.event_commitment,
            Felt252::ZERO,
            Felt252::ZERO,
            self.parent_block_hash,
        ]
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct StarknetBlock0_13_2 {
    pub block_hash_version: Felt252,
    pub block_number: Felt252,
    pub state_root: Felt252,
    pub sequencer_address: Felt252,
    pub block_timestamp: Felt252,
    pub concatenated_counts: Felt252,
    pub state_diff_commitment: Felt252,
    pub transaction_commitment: Felt252,
    pub event_commitment: Felt252,
    pub receipt_commitment: Felt252,
    pub l1_gas_price_wei: Felt252,
    pub l1_gas_price_fri: Felt252,
    pub l1_data_gas_price_wei: Felt252,
    pub l1_data_gas_price_fri: Felt252,
    pub protocol_version: Felt252,
    pub parent_block_hash: Felt252,
}

impl StarknetBlock0_13_2 {
    pub fn from_hash_fields(fields: Vec<Felt252>) -> Self {
        Self {
            block_hash_version: fields[0],
            block_number: fields[1],
            state_root: fields[2],
            sequencer_address: fields[3],
            block_timestamp: fields[4],
            concatenated_counts: fields[5],
            state_diff_commitment: fields[6],
            transaction_commitment: fields[7],
            event_commitment: fields[8],
            receipt_commitment: fields[9],
            l1_gas_price_wei: fields[10],
            l1_gas_price_fri: fields[11],
            l1_data_gas_price_wei: fields[12],
            l1_data_gas_price_fri: fields[13],
            protocol_version: fields[14], // index 15 is a zero for hashing
            parent_block_hash: fields[16],
        }
    }

    pub fn from_fields(fields: Vec<Felt252>) -> Self {
        Self {
            block_hash_version: fields[0],
            block_number: fields[1],
            state_root: fields[2],
            sequencer_address: fields[3],
            block_timestamp: fields[4],
            concatenated_counts: fields[5],
            state_diff_commitment: fields[6],
            transaction_commitment: fields[7],
            event_commitment: fields[8],
            receipt_commitment: fields[9],
            l1_gas_price_wei: fields[10],
            l1_gas_price_fri: fields[11],
            l1_data_gas_price_wei: fields[12],
            l1_data_gas_price_fri: fields[13],
            protocol_version: fields[14],
            parent_block_hash: fields[15],
        }
    }

    pub fn from_block(block: &Block) -> Self {
        // Calculate total events and transactions
        let total_events: usize = block.transaction_receipts.iter().map(|(_, events)| events.len()).sum();
        let total_transactions: usize = block.transactions.len();

        // Create concatenated counts similar to Python's concat_counts()
        let mut concat_counts = [0u8; 32];
        // Transaction count (8 bytes)
        concat_counts[0..8].copy_from_slice(&(total_transactions as u64).to_be_bytes());
        // Event count (8 bytes)
        concat_counts[8..16].copy_from_slice(&(total_events as u64).to_be_bytes());
        // State diff length (8 bytes)
        concat_counts[16..24].copy_from_slice(&(block.state_diff_length.unwrap_or(0) as u64).to_be_bytes());
        // L1 DA mode (1 byte)
        concat_counts[24] = if block.l1_da_mode == L1DataAvailabilityMode::Blob {
            0b10000000
        } else {
            0
        };

        Self {
            block_hash_version: Felt252::from_hex("0x535441524b4e45545f424c4f434b5f4841534830").unwrap(), // "STARKNET_BLOCK_HASH0"
            block_number: Felt252::from(block.block_number.get()),
            state_root: Felt252::from_bytes_be(&block.state_commitment.as_inner().to_be_bytes()),
            sequencer_address: Felt252::from_bytes_be(&block.sequencer_address.ok_or(Felt252::ZERO).unwrap().as_inner().to_be_bytes()),
            block_timestamp: Felt252::from(block.timestamp.get()),
            concatenated_counts: Felt252::from_bytes_be(&concat_counts),
            state_diff_commitment: Felt252::from_bytes_be(&block.state_diff_commitment.unwrap().as_inner().to_be_bytes()),
            transaction_commitment: Felt252::from_bytes_be(&block.transaction_commitment.as_inner().to_be_bytes()),
            event_commitment: Felt252::from_bytes_be(&block.event_commitment.as_inner().to_be_bytes()),
            receipt_commitment: Felt252::from_bytes_be(&block.receipt_commitment.unwrap().as_inner().to_be_bytes()),
            l1_gas_price_wei: Felt252::from(block.l1_gas_price.price_in_wei.0).into(),
            l1_gas_price_fri: Felt252::from(block.l1_gas_price.price_in_fri.0).into(),
            l1_data_gas_price_wei: Felt252::from(block.l1_data_gas_price.price_in_wei.0).into(),
            l1_data_gas_price_fri: Felt252::from(block.l1_data_gas_price.price_in_fri.0).into(),
            protocol_version: Felt252::from_bytes_be_slice(block.starknet_version.to_string().as_bytes()),
            parent_block_hash: Felt252::from_bytes_be(&block.parent_block_hash.as_inner().to_be_bytes()),
        }
    }

    pub fn n_fields() -> usize {
        17
    }

    pub fn n_hash_fields() -> usize {
        17
    }

    pub fn to_hash_fields(&self) -> Vec<Felt252> {
        vec![
            self.block_hash_version,
            self.block_number,
            self.state_root,
            self.sequencer_address,
            self.block_timestamp,
            self.concatenated_counts,
            self.state_diff_commitment,
            self.transaction_commitment,
            self.event_commitment,
            self.receipt_commitment,
            self.l1_gas_price_wei,
            self.l1_gas_price_fri,
            self.l1_data_gas_price_wei,
            self.l1_data_gas_price_fri,
            self.protocol_version,
            Felt252::ZERO,
            self.parent_block_hash,
        ]
    }
}
