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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct Proofs {
    pub mmr_meta: MmrMeta,
    pub headers: Vec<Header>,
    pub headers_with_mmr: Vec<(MmrMeta, Header)>,
    pub accounts: Vec<Account>,
    pub storages: Vec<Storage>,
    pub transactions: Vec<Transaction>,
    pub transaction_receipts: Vec<Receipt>,
}
