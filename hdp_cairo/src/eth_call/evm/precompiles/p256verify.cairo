// ============================================================================
// EVM P256 Verify Precompile
// ============================================================================
// Validates secp256r1 signatures with fixed gas cost.

use starknet::secp256_trait::{Secp256Trait, is_valid_signature};
use starknet::secp256r1::Secp256r1Point;
use starknet::{EthAddress, SyscallResultTrait};
use crate::eth_call::evm::errors::EVMError;
use crate::eth_call::evm::precompiles::Precompile;
use crate::eth_call::utils::traits::bytes::FromBytes;

const P256VERIFY_PRECOMPILE_GAS_COST: u64 = 3450;

const ONE_32_BYTES: [u8; 32] = [
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
];

pub impl P256Verify of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x100.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let gas = P256VERIFY_PRECOMPILE_GAS_COST;

        if input.len() != 160 {
            return Result::Ok((gas, [].span()));
        }

        let message_hash = input.slice(0, 32);
        let message_hash: Option<u256> = message_hash.from_be_bytes();
        let message_hash_is_none = message_hash.is_none();
        let message_hash = message_hash.unwrap_or(0);
        if message_hash_is_none {
            return Result::Ok((gas, [].span()));
        }

        let r: Option<u256> = input.slice(32, 32).from_be_bytes();
        let r_is_none = r.is_none();
        let r = r.unwrap_or(0);
        if r_is_none {
            return Result::Ok((gas, [].span()));
        }

        let s: Option<u256> = input.slice(64, 32).from_be_bytes();
        let s_is_none = s.is_none();
        let s = s.unwrap_or(0);
        if s_is_none {
            return Result::Ok((gas, [].span()));
        }

        let x: Option<u256> = input.slice(96, 32).from_be_bytes();
        let x_is_none = x.is_none();
        let x = x.unwrap_or(0);
        if x_is_none {
            return Result::Ok((gas, [].span()));
        }

        let y: Option<u256> = input.slice(128, 32).from_be_bytes();
        let y_is_none = y.is_none();
        let y = y.unwrap_or(0);
        if y_is_none {
            return Result::Ok((gas, [].span()));
        }

        let public_key: Option<Secp256r1Point> = Secp256Trait::secp256_ec_new_syscall(x, y)
            .unwrap_syscall();
        let public_key = if let Option::Some(public_key) = public_key {
            public_key
        } else {
            return Result::Ok((gas, [].span()));
        };

        if !is_valid_signature(message_hash, r, s, public_key) {
            return Result::Ok((gas, [].span()));
        }

        return Result::Ok((gas, ONE_32_BYTES.span()));
    }
}

#[cfg(test)]
mod tests {
    use core::array::ArrayTrait;
    use crate::eth_call::evm::precompiles::p256verify::P256Verify;
    use crate::eth_call::utils::traits::bytes::{FromBytes, ToBytes};


    // source:
    // <https://github.com/ethereum/go-ethereum/pull/27540/files#diff-3548292e7ee4a75fc8146397c6baf5c969f6fe6cd9355df322cdb4f11103e004>
    #[test]
    fn test_p256verify_precompile() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();
        let y = 0x7618b065f9832de4ca6ca971a7a1adc826d0f7c00181a5fb2ddf79ae00b4e10e_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);
        calldata.append_span(y);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        let result: u256 = result.from_be_bytes().expect('p256verify_precompile_test');
        assert_eq!(result, 0x01);
        assert_eq!(gas, 3450);
    }


    #[test]
    fn test_p256verify_precompile_input_too_short() {
        let msg_hash = 0x4cee90eb86eaa050036147a12d49004b6b9c72bd725d39d4785011fe190f0b4d_u256
            .to_be_bytes_padded();
        let r = 0xa73bd4903f0ce3b639bbbf6e8e80d16931ff4bcf5993d58468e8fb19086e8cac_u256
            .to_be_bytes_padded();
        let s = 0x36dbcd03009df8c59286b162af3bd7fcc0450c9aa81be5d10d312af6c66b1d60_u256
            .to_be_bytes_padded();
        let x = 0x4aebd3099c618202fcfe16ae7770b0c49ab5eadf74b754204a3bb6060e44eff3_u256
            .to_be_bytes_padded();

        let mut calldata = array![];
        calldata.append_span(msg_hash);
        calldata.append_span(r);
        calldata.append_span(s);
        calldata.append_span(x);

        let (gas, result) = P256Verify::exec(calldata.span()).unwrap();

        assert_eq!(result, [].span());
        assert_eq!(gas, 3450);
    }
}
