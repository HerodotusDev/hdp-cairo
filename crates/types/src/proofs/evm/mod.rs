use super::HeaderMmrMeta;
use account::Account;
use receipt::Receipt;
use serde::{Deserialize, Serialize};
use storage::Storage;
use transaction::Transaction;

pub mod account;
pub mod receipt;
pub mod storage;
pub mod transaction;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta>,
    pub accounts: Vec<Account>,
    pub storages: Vec<Storage>,
    pub transactions: Vec<Transaction>,
    pub transaction_receipts: Vec<Receipt>,
}
