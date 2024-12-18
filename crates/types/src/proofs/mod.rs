pub mod account;
pub mod header;
pub mod mmr;
pub mod mpt;
pub mod receipt;
pub mod storage;
pub mod transaction;

use account::Account;
use header::Header;
use mmr::MmrMeta;
use receipt::Receipt;
use serde::{Deserialize, Serialize};
use storage::Storage;
use transaction::Transaction;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default, Hash)]
pub struct HeaderMmrMeta {
    pub headers: Vec<Header>,
    pub mmr_meta: MmrMeta,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub headers_with_mmr: Vec<HeaderMmrMeta>,
    pub accounts: Vec<Account>,
    pub storages: Vec<Storage>,
    pub transactions: Vec<Transaction>,
    pub transaction_receipts: Vec<Receipt>,
}
