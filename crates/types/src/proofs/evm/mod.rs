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
    #[allow(clippy::len_without_is_empty)]
    pub fn len(&self) -> usize {
        self.headers_with_mmr.len() + self.accounts.len() + self.storages.len() + self.transactions.len() + self.transaction_receipts.len()
    }
}
