use core::array::ArrayTrait;
use core::option::OptionTrait;
use starknet::EthAddress;
use crate::eth_call::evm::errors::{EVMError, ensure};
use crate::eth_call::evm::precompiles::Precompile;
use crate::eth_call::utils::crypto::blake2_compress::compress;
use crate::eth_call::utils::traits::bytes::{FromBytes, ToBytes};

const GF_ROUND: u64 = 1;
const INPUT_LENGTH: usize = 213;

pub impl Blake2f of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x9.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        ensure(
            input.len() == INPUT_LENGTH, EVMError::InvalidParameter('Blake2: wrong input length'),
        )?;

        let f = match (*input[212]).into() {
            0 => false,
            1 => true,
            _ => {
                return Result::Err(EVMError::InvalidParameter('Blake2: wrong final indicator'));
            },
        };

        let rounds: u32 = input
            .slice(0, 4)
            .from_be_bytes()
            .ok_or(EVMError::TypeConversionError('extraction of u32 failed'))?;

        let gas = (GF_ROUND * rounds.into()).into();

        let mut h: Array<u64> = Default::default();
        let mut m: Array<u64> = Default::default();

        let mut i = 0;
        let mut pos = 4;
        while i != 8 {
            // safe unwrap, because we have made sure of the input length to be 213
            h.append(input.slice(pos, 8).from_le_bytes().unwrap());
            i += 1;
            pos += 8;
        }

        let mut i = 0;
        let mut pos = 68;
        while i != 16 {
            // safe unwrap, because we have made sure of the input length to be 213
            m.append(input.slice(pos, 8).from_le_bytes().unwrap());
            i += 1;
            pos += 8;
        }

        let mut t: Array<u64> = Default::default();

        // safe unwrap, because we have made sure of the input length to be 213
        t.append(input.slice(196, 8).from_le_bytes().unwrap());
        // safe unwrap, because we have made sure of the input length to be 213
        t.append(input.slice(204, 8).from_le_bytes().unwrap());

        let res = compress(rounds, h.span(), m.span(), t.span(), f);

        let mut return_data: Array<u8> = Default::default();

        let mut i = 0;
        while i != res.len() {
            let bytes = (*res[i]).to_le_bytes_padded();
            return_data.append_span(bytes);

            i += 1;
        }

        Result::Ok((gas, return_data.span()))
    }
}

#[cfg(test)]
mod tests {
    use core::array::SpanTrait;
    use crate::eth_call::evm::errors::EVMError;
    use crate::eth_call::evm::precompiles::blake2f::Blake2f;
    use crate::eth_call::evm::test_data::test_data_blake2f::{
        blake2_precompile_fail_wrong_length_input_1_test_case,
        blake2_precompile_fail_wrong_length_input_2_test_case,
        blake2_precompile_fail_wrong_length_input_3_test_case, blake2_precompile_pass_0_test_case,
        blake2_precompile_pass_1_test_case, blake2_precompile_pass_2_test_case,
    };
    use crate::eth_call::utils::traits::bytes::FromBytes;

    #[test]
    fn test_blake2_precompile_fail_empty_input() {
        let calldata = array![];

        let res = Blake2f::exec(calldata.span());
        assert_eq!(res, Result::Err(EVMError::InvalidParameter('Blake2: wrong input length')));
    }

    #[test]
    fn test_blake2_precompile_fail_wrong_length_input_1() {
        let (calldata, _) = blake2_precompile_fail_wrong_length_input_1_test_case();

        let res = Blake2f::exec(calldata);
        assert_eq!(res, Result::Err(EVMError::InvalidParameter('Blake2: wrong input length')));
    }
    #[test]
    fn test_blake2_precompile_fail_wrong_length_input_2() {
        let (calldata, _) = blake2_precompile_fail_wrong_length_input_2_test_case();

        let res = Blake2f::exec(calldata);
        assert_eq!(res, Result::Err(EVMError::InvalidParameter('Blake2: wrong input length')));
    }

    #[test]
    fn test_blake2_precompile_fail_wrong_final_block_indicator_flag() {
        let (calldata, _) = blake2_precompile_fail_wrong_length_input_3_test_case();

        let res = Blake2f::exec(calldata);
        assert_eq!(res, Result::Err(EVMError::InvalidParameter('Blake2: wrong final indicator')));
    }

    #[test]
    fn test_blake2_precompile_pass_1() {
        let (calldata, expected_result) = blake2_precompile_pass_1_test_case();
        let rounds: u32 = calldata.slice(0, 4).from_be_bytes().unwrap();

        let (gas, result) = Blake2f::exec(calldata).unwrap();

        assert_eq!(result, expected_result);
        assert_eq!(gas, rounds.into());
    }

    #[test]
    fn test_blake2_precompile_pass_0() {
        let (calldata, expected_result) = blake2_precompile_pass_0_test_case();
        let rounds: u32 = calldata.slice(0, 4).from_be_bytes().unwrap();

        let (gas, result) = Blake2f::exec(calldata).unwrap();

        assert_eq!(result, expected_result);
        assert_eq!(gas, rounds.into());
    }

    #[test]
    fn test_blake2_precompile_pass_2() {
        let (calldata, expected_result) = blake2_precompile_pass_2_test_case();
        let rounds: u32 = calldata.slice(0, 4).from_be_bytes().unwrap();

        let (gas, result) = Blake2f::exec(calldata).unwrap();

        assert_eq!(result, expected_result);
        assert_eq!(gas, rounds.into());
    }
}
