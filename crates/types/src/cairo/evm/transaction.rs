use alloy::{
    consensus::{
        transaction::{SignerRecoverable, TxEnvelope},
        TxType,
    },
    rpc::types::Transaction,
};
use alloy_rlp::{Decodable, Encodable};
use strum_macros::FromRepr;

use crate::cairo::{evm::error::CairoEvmError, structs::Uint256};

#[derive(FromRepr, Debug, PartialEq, Eq)]
pub enum FunctionId {
    Nonce = 0,
    GasPrice = 1,
    GasLimit = 2,
    Receiver = 3,
    Value = 4,
    Data = 5,
    V = 6,
    R = 7,
    S = 8,
    ChainId = 9,
    AccessList = 10,
    MaxFeePerGas = 11,
    MaxPriorityFeePerGas = 12,
    MaxFeePerBlobGas = 13,
    BlobVersionedHashes = 14,
    AuthorizationList = 15,
    TxType = 16,
    Sender = 17,
    Hash = 18,
}

pub struct CairoTransaction(TxEnvelope);

impl CairoTransaction {
    pub fn new(value: TxEnvelope) -> Self {
        Self(value)
    }

    pub fn hash(&self) -> Uint256 {
        self.0.tx_hash().to_owned().into()
    }

    pub fn signature_hash(&self) -> Uint256 {
        self.0.signature_hash().into()
    }

    pub fn handle_legacy_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        let (fields, signature, _) = self
            .0
            .as_legacy()
            .ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Legacy but as_legacy() returned None",
            })?
            .clone()
            .into_parts();

        Ok(match function_id {
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasPrice => fields.gas_price.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => fields
                .to
                .to()
                .copied()
                .ok_or(CairoEvmError::MissingField {
                    what: "evm::transaction",
                    field: "to",
                })?
                .into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self
                .0
                .recover_signer()
                .map_err(|e| CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: format!("recover_signer failed: {e}"),
                })?
                .into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            other => {
                return Err(CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: match other {
                        FunctionId::Data => "Data",
                        FunctionId::AccessList => "AccessList",
                        FunctionId::BlobVersionedHashes => "BlobVersionedHashes",
                        FunctionId::AuthorizationList => "AuthorizationList",
                        FunctionId::MaxFeePerGas => "MaxFeePerGas",
                        FunctionId::MaxPriorityFeePerGas => "MaxPriorityFeePerGas",
                        FunctionId::MaxFeePerBlobGas => "MaxFeePerBlobGas",
                        FunctionId::ChainId => "ChainId",
                        _ => "Unknown",
                    }
                    .to_string(),
                });
            }
        })
    }

    pub fn handle_eip_155_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        if function_id == FunctionId::ChainId {
            let legacy = self.0.as_legacy().ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Legacy but as_legacy() returned None",
            })?;
            Ok(legacy
                .tx()
                .chain_id
                .ok_or(CairoEvmError::MissingField {
                    what: "evm::transaction",
                    field: "chain_id",
                })?
                .into())
        } else {
            self.handle_legacy_tx(function_id)
        }
    }

    pub fn handle_eip_2930_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        let (fields, signature, _) = self
            .0
            .as_eip2930()
            .ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Eip2930 but as_eip2930() returned None",
            })?
            .clone()
            .into_parts();

        Ok(match function_id {
            FunctionId::ChainId => fields.chain_id.into(),
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasPrice => fields.gas_price.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => fields
                .to
                .to()
                .copied()
                .ok_or(CairoEvmError::MissingField {
                    what: "evm::transaction",
                    field: "to",
                })?
                .into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self
                .0
                .recover_signer()
                .map_err(|e| CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: format!("recover_signer failed: {e}"),
                })?
                .into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            other => {
                return Err(CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: match other {
                        FunctionId::AccessList => "AccessList",
                        FunctionId::Data => "Data",
                        _ => "Unknown",
                    }
                    .to_string(),
                });
            }
        })
    }

    pub fn handle_eip_1559_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        let (fields, signature, _) = self
            .0
            .as_eip1559()
            .ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Eip1559 but as_eip1559() returned None",
            })?
            .clone()
            .into_parts();

        Ok(match function_id {
            FunctionId::ChainId => fields.chain_id.into(),
            FunctionId::MaxPriorityFeePerGas => fields.max_priority_fee_per_gas.into(),
            FunctionId::MaxFeePerGas => fields.max_fee_per_gas.into(),
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => fields
                .to
                .to()
                .copied()
                .ok_or(CairoEvmError::MissingField {
                    what: "evm::transaction",
                    field: "to",
                })?
                .into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self
                .0
                .recover_signer()
                .map_err(|e| CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: format!("recover_signer failed: {e}"),
                })?
                .into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            other => {
                return Err(CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: match other {
                        FunctionId::AccessList => "AccessList",
                        FunctionId::Data => "Data",
                        _ => "Unknown",
                    }
                    .to_string(),
                });
            }
        })
    }

    pub fn handle_eip_4844_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        let (fields, signature, _) = self
            .0
            .as_eip4844()
            .ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Eip4844 but as_eip4844() returned None",
            })?
            .clone()
            .into_parts();

        Ok(match function_id {
            FunctionId::ChainId => fields.tx().chain_id.into(),
            FunctionId::MaxPriorityFeePerGas => fields.tx().max_priority_fee_per_gas.into(),
            FunctionId::MaxFeePerGas => fields.tx().max_fee_per_gas.into(),
            FunctionId::MaxFeePerBlobGas => fields.tx().max_fee_per_blob_gas.into(),
            FunctionId::Nonce => fields.tx().nonce.into(),
            FunctionId::GasLimit => fields.tx().gas_limit.into(),
            FunctionId::Receiver => fields.tx().to.into(),
            FunctionId::Value => fields.tx().value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self
                .0
                .recover_signer()
                .map_err(|e| CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: format!("recover_signer failed: {e}"),
                })?
                .into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            other => {
                return Err(CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: match other {
                        FunctionId::BlobVersionedHashes => "BlobVersionedHashes",
                        FunctionId::AccessList => "AccessList",
                        FunctionId::Data => "Data",
                        _ => "Unknown",
                    }
                    .to_string(),
                });
            }
        })
    }

    pub fn handle_eip_7702_tx(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        let (fields, signature, _) = self
            .0
            .as_eip7702()
            .ok_or(CairoEvmError::InternalInvariant {
                what: "evm::transaction",
                info: "tx_type=Eip7702 but as_eip7702() returned None",
            })?
            .clone()
            .into_parts();

        Ok(match function_id {
            FunctionId::ChainId => fields.chain_id.into(),
            FunctionId::MaxPriorityFeePerGas => fields.max_priority_fee_per_gas.into(),
            FunctionId::MaxFeePerGas => fields.max_fee_per_gas.into(),
            FunctionId::Nonce => fields.nonce.into(),
            FunctionId::GasLimit => fields.gas_limit.into(),
            FunctionId::Receiver => fields.to.into(),
            FunctionId::Value => fields.value.into(),
            FunctionId::V => Uint256::from(signature.v()),
            FunctionId::R => signature.r().into(),
            FunctionId::S => signature.s().into(),
            FunctionId::Sender => self
                .0
                .recover_signer()
                .map_err(|e| CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: format!("recover_signer failed: {e}"),
                })?
                .into(),
            FunctionId::Hash => self.hash(),
            FunctionId::TxType => (self.0.tx_type() as u64).into(),
            other => {
                return Err(CairoEvmError::UnsupportedFunction {
                    what: "evm::transaction",
                    function_id: match other {
                        FunctionId::AccessList => "AccessList",
                        FunctionId::Data => "Data",
                        FunctionId::AuthorizationList => "AuthorizationList",
                        _ => "Unknown",
                    }
                    .to_string(),
                });
            }
        })
    }

    pub fn handle(&self, function_id: FunctionId) -> Result<Uint256, CairoEvmError> {
        match self.0.tx_type() {
            TxType::Legacy => {
                if self.0.is_replay_protected() {
                    self.handle_eip_155_tx(function_id)
                } else {
                    self.handle_legacy_tx(function_id)
                }
            }
            TxType::Eip2930 => self.handle_eip_2930_tx(function_id),
            TxType::Eip1559 => self.handle_eip_1559_tx(function_id),
            TxType::Eip4844 => self.handle_eip_4844_tx(function_id),
            TxType::Eip7702 => self.handle_eip_7702_tx(function_id),
        }
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.0.encode(&mut buffer);
        buffer
    }

    pub fn try_rlp_decode(mut rlp: &[u8]) -> Result<Self, CairoEvmError> {
        <TxEnvelope>::decode(&mut rlp).map(Self).map_err(|e| CairoEvmError::RlpDecode {
            what: "evm::transaction",
            err: e.to_string(),
        })
    }
}

impl From<Transaction> for CairoTransaction {
    fn from(value: Transaction) -> Self {
        Self(value.into_inner())
    }
}
