use account::Account;
use header::Header;
use receipt::Receipt;
use serde::{Deserialize, Serialize};
use storage::Storage;
use transaction::Transaction;

use super::header::HeaderMmrMeta;

pub mod account;
pub mod header;
pub mod receipt;
pub mod storage;
pub mod transaction;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta<Header>>,
    pub accounts: Vec<Account>,
    pub storages: Vec<Storage>,
    pub transactions: Vec<Transaction>,
    pub transaction_receipts: Vec<Receipt>,
}

impl Proofs {
    pub fn len(&self) -> usize {
        self.headers_with_mmr.len() + self.accounts.len() + self.storages.len() + self.transactions.len() + self.transaction_receipts.len()
    }

    pub fn is_empty(&self) -> bool {
        self.headers_with_mmr.is_empty()
            && self.accounts.is_empty()
            && self.storages.is_empty()
            && self.transactions.is_empty()
            && self.transaction_receipts.is_empty()
    }
}
