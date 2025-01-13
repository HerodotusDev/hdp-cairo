use cairo_vm::Felt252;
use strum_macros::FromRepr;
use pathfinder_gateway_types::reply::Block;

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

    pub fn parent_block_hash(&self) -> Felt252 {
        Felt252::from_bytes_be(&self.0.parent_block_hash.as_inner().to_be_bytes())
    }

    pub fn block_number(&self) -> Felt252 {
        Felt252::from(self.0.block_number.get())
    }

    pub fn state_root(&self) -> Felt252 {
        Felt252::from_bytes_be(&self.0.state_commitment.as_inner().to_be_bytes())
    }

    pub fn sequencer_address(&self) -> Felt252 {
        Felt252::from_bytes_be(&self.0.sequencer_address.ok_or(Felt252::ZERO).unwrap().as_inner().to_be_bytes())
    }

    pub fn block_timestamp(&self) -> Felt252 {
        Felt252::from(self.0.timestamp.get())
    }

    pub fn transaction_count(&self) -> Felt252 {
        Felt252::from(self.0.transactions.len())
    }

    pub fn transaction_commitment(&self) -> Felt252 {
        Felt252::from_bytes_be(&self.0.transaction_commitment.as_inner().to_be_bytes())
    }

    pub fn event_count(&self) -> Felt252 {
        let total_events: usize = self.0.transaction_receipts
            .iter()
            .map(|(_, events)| events.len())
            .sum();
        
        Felt252::from(total_events)
    }

    pub fn event_commitment(&self) -> Felt252 {
        Felt252::from_bytes_be(&self.0.event_commitment.as_inner().to_be_bytes())
    }

    // v0.13.2+ specific fields
    pub fn state_diff_commitment(&self) -> Option<Felt252> {
        self.0.state_diff_commitment.map(|f| Felt252::from_bytes_be(&f.as_inner().to_be_bytes()))
    }

    pub fn state_diff_length(&self) -> Option<Felt252> {
        self.0.state_diff_length.map(|f| Felt252::from(f))
    }

    pub fn receipt_commitment(&self) -> Option<Felt252> {
        self.0.receipt_commitment.map(|f| Felt252::from_bytes_be(&f.as_inner().to_be_bytes()))
    }

    pub fn l1_gas_price_wei(&self) -> Felt252 {
        Felt252::from(self.0.l1_gas_price.price_in_wei.0)
    }

    pub fn l1_gas_price_fri(&self) -> Felt252 {
        Felt252::from(self.0.l1_gas_price.price_in_fri.0)
    }

    pub fn l1_data_gas_price_wei(&self) -> Felt252 {
        Felt252::from(self.0.l1_data_gas_price.price_in_wei.0)
    }

    pub fn l1_data_gas_price_fri(&self) -> Felt252 {
        Felt252::from(self.0.l1_data_gas_price.price_in_fri.0)
    }

    pub fn version(&self) -> Felt252 {
        Felt252::from(self.0.starknet_version.as_u32())
    }

    pub fn handle(&self, function_id: FunctionId) -> Felt252 {
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
            FunctionId::StateDiffCommitment => self.state_diff_commitment().unwrap_or(Felt252::ZERO),
            FunctionId::StateDiffLength => self.state_diff_length().unwrap_or(Felt252::ZERO),
            FunctionId::ReceiptCommitment => self.receipt_commitment().unwrap_or(Felt252::ZERO),
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