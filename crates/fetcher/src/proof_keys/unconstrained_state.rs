use std::collections::HashSet;

use types::keys;

use super::FlattenedKey;

#[derive(Debug, Default)]
pub struct ProofKeys {
    pub bytecode: HashSet<keys::evm::account::Key>,
}

impl ProofKeys {
    pub fn to_flattened_keys(&self, chain_id: u128) -> HashSet<FlattenedKey> {
        let mut flattened = HashSet::new();

        for key in self.bytecode.iter().filter(|k| k.chain_id == chain_id) {
            flattened.insert(FlattenedKey {
                chain_id: key.chain_id,
                block_number: key.block_number,
            });
        }

        flattened
    }
}
