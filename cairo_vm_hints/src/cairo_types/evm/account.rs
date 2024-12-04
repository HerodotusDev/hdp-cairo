use crate::cairo_types::structs::Uint256;
use alloy::{
    primitives::{B256, U256},
    rpc::types::EIP1186AccountProofResponse,
};

use alloy_rlp::{Decodable, Encodable, RlpDecodable, RlpEncodable};

#[derive(Debug, RlpDecodable, RlpEncodable, PartialEq)]
pub struct CairoAccount {
    pub nonce: u64,
    pub balance: U256,
    pub storage_hash: B256,
    pub code_hash: B256,
}

impl CairoAccount {
    pub fn new(nonce: u64, balance: U256, storage_hash: B256, code_hash: B256) -> Self {
        Self {
            nonce,
            balance,
            storage_hash,
            code_hash,
        }
    }

    pub fn nonce(&self) -> Uint256 {
        self.nonce.into()
    }
    pub fn balance(&self) -> Uint256 {
        self.balance.into()
    }
    pub fn storage_hash(&self) -> Uint256 {
        self.storage_hash.into()
    }
    pub fn code_hash(&self) -> Uint256 {
        self.code_hash.into()
    }

    pub fn rlp_encode(&self) -> Vec<u8> {
        let mut buffer = Vec::<u8>::new();
        self.encode(&mut buffer);
        buffer
    }

    pub fn rlp_decode(mut rlp: &[u8]) -> Self {
        <Self>::decode(&mut rlp).unwrap()
    }
}

impl From<EIP1186AccountProofResponse> for CairoAccount {
    fn from(account_from_rpc: EIP1186AccountProofResponse) -> Self {
        Self {
            nonce: account_from_rpc.nonce,
            balance: account_from_rpc.balance,
            storage_hash: account_from_rpc.storage_hash,
            code_hash: account_from_rpc.code_hash,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::hex;
    use alloy::primitives::U256;
    use std::str::FromStr;

    #[test]
    fn test_get_account_rlp() {
        let account = CairoAccount::new(
            1,
            U256::from(0),
            B256::from_str("0x1c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185").unwrap(),
            B256::from_str("0xcd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c").unwrap(),
        );
        let account_rlp = account.rlp_encode();
        assert_eq!(
            hex::encode(account_rlp),
            "f8440180a01c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185a0cd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c"
        );

        let account = CairoAccount::new(
            2,
            U256::from(0),
            B256::from_str("0x1c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185").unwrap(),
            B256::from_str("0xcd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c").unwrap(),
        );
        let account_rlp = account.rlp_encode();
        assert_eq!(
            hex::encode(account_rlp),
            "f8440280a01c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185a0cd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c"
        );

        let account = CairoAccount::new(
            2,
            U256::from(0x1),
            B256::from_str("0x1c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185").unwrap(),
            B256::from_str("0xcd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c").unwrap(),
        );
        let account_rlp = account.rlp_encode();
        assert_eq!(
            hex::encode(account_rlp),
            "f8440201a01c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185a0cd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c"
        );
    }

    #[test]
    fn test_decode_account_rlp() {
        let account_rlp = "f8440180a01c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185a0cd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c";
        let account = CairoAccount::rlp_decode(hex::decode(account_rlp).unwrap().as_slice());
        assert_eq!(
            account,
            CairoAccount::new(
                1,
                U256::from(0),
                B256::from_str("0x1c35dfde2b62d99d3a74fda76446b60962c4656814bdd7815eb6e5b8be1e7185").unwrap(),
                B256::from_str("0xcd4f25236fff0ccac15e82bf4581beb08e95e1b5ba89de6031c75893cd91245c").unwrap()
            )
        );
    }
}
