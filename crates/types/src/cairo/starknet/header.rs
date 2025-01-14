use cairo_vm::Felt252;
use strum_macros::FromRepr;
pub use pathfinder_gateway_types::reply::Block;

use crate::cairo::structs::Felt;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Parent = 0,
    BlockNumber = 1,
    StateRoot = 2,
    SequencerAddress = 3,
    BlockTimestamp = 4,
    TransactionCount = 5,
    TransactionCommitment = 6,
    EventCount = 7,
    EventCommitment = 8,
    StateDiffCommitment = 9,
    StateDiffLength = 10,
    ReceiptCommitment = 11,
    L1GasPriceWei = 12,
    L1GasPriceFri = 13,
    L1DataGasPriceWei = 14,
    L1DataGasPriceFri = 15,
    Version = 16
}

pub struct CairoHeader(Block);

impl CairoHeader {
    pub fn new(value: Block) -> Self {
        Self(value)
    }

    pub fn parent_block_hash(&self) -> Felt {
        Felt252::from_bytes_be(&self.0.parent_block_hash.as_inner().to_be_bytes()).into()
    }

    pub fn block_number(&self) -> Felt {
        Felt252::from(self.0.block_number.get()).into()
    }

    pub fn state_root(&self) -> Felt {
        Felt252::from_bytes_be(&self.0.state_commitment.as_inner().to_be_bytes()).into()
    }

    pub fn sequencer_address(&self) -> Felt {
        Felt252::from_bytes_be(&self.0.sequencer_address.ok_or(Felt252::ZERO).unwrap().as_inner().to_be_bytes()).into()
    }

    pub fn block_timestamp(&self) -> Felt {
        Felt252::from(self.0.timestamp.get()).into()
    }

    pub fn transaction_count(&self) -> Felt {
        Felt252::from(self.0.transactions.len()).into()
    }

    pub fn transaction_commitment(&self) -> Felt {
        Felt252::from_bytes_be(&self.0.transaction_commitment.as_inner().to_be_bytes()).into()
    }

    pub fn event_count(&self) -> Felt {
        let total_events: usize = self.0.transaction_receipts
            .iter()
            .map(|(_, events)| events.len())
            .sum();
        
        Felt252::from(total_events).into()
    }

    pub fn event_commitment(&self) -> Felt {
        Felt252::from_bytes_be(&self.0.event_commitment.as_inner().to_be_bytes()).into()
    }

    // v0.13.2+ specific fields
    pub fn state_diff_commitment(&self) -> Option<Felt> {
        self.0.state_diff_commitment.map(|f| Felt252::from_bytes_be(&f.as_inner().to_be_bytes()).into())
    }

    pub fn state_diff_length(&self) -> Option<Felt> {
        self.0.state_diff_length.map(|f| Felt252::from(f).into())
    }

    pub fn receipt_commitment(&self) -> Option<Felt> {
        self.0.receipt_commitment.map(|f| Felt252::from_bytes_be(&f.as_inner().to_be_bytes()).into())
    }

    pub fn l1_gas_price_wei(&self) -> Felt {
        Felt252::from(self.0.l1_gas_price.price_in_wei.0).into()
    }

    pub fn l1_gas_price_fri(&self) -> Felt {
        Felt252::from(self.0.l1_gas_price.price_in_fri.0).into()
    }

    pub fn l1_data_gas_price_wei(&self) -> Felt {
        Felt252::from(self.0.l1_data_gas_price.price_in_wei.0).into()
    }

    pub fn l1_data_gas_price_fri(&self) -> Felt {
        Felt252::from(self.0.l1_data_gas_price.price_in_fri.0).into()
    }

    pub fn version(&self) -> Felt {
        Felt252::from(self.0.starknet_version.as_u32()).into()
    }

    pub fn handle(&self, function_id: FunctionId) -> Felt {
        match function_id {
            FunctionId::Parent => self.parent_block_hash(),
            FunctionId::BlockNumber => self.block_number(),
            FunctionId::StateRoot => self.state_root(),
            FunctionId::SequencerAddress => self.sequencer_address(),
            FunctionId::BlockTimestamp => self.block_timestamp(),
            FunctionId::TransactionCount => self.transaction_count(),
            FunctionId::TransactionCommitment => self.transaction_commitment(),
            FunctionId::EventCount => self.event_count(),
            FunctionId::EventCommitment => self.event_commitment(),
            FunctionId::StateDiffCommitment => self.state_diff_commitment().unwrap_or_else(|| Felt252::ZERO.into()),
            FunctionId::StateDiffLength => self.state_diff_length().unwrap_or_else(|| Felt252::ZERO.into()),
            FunctionId::ReceiptCommitment => self.receipt_commitment().unwrap_or_else(|| Felt252::ZERO.into()),
            FunctionId::L1GasPriceWei => self.l1_gas_price_wei(),
            FunctionId::L1GasPriceFri => self.l1_gas_price_fri(),
            FunctionId::L1DataGasPriceWei => self.l1_data_gas_price_wei(),
            FunctionId::L1DataGasPriceFri => self.l1_data_gas_price_fri(),
            FunctionId::Version => self.version(),
        }
    }
}

impl From<Block> for CairoHeader {
    fn from(value: Block) -> Self {
        Self(value)
    }
}