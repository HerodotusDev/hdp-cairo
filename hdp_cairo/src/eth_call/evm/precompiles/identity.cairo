use starknet::EthAddress;
use crate::eth_call::evm::errors::EVMError;
use crate::eth_call::evm::precompiles::Precompile;

const BASE_COST: u64 = 15;
const COST_PER_WORD: u64 = 3;

pub impl Identity of Precompile {
    #[inline(always)]
    fn address() -> EthAddress {
        0x4.try_into().unwrap()
    }

    fn exec(input: Span<u8>) -> Result<(u64, Span<u8>), EVMError> {
        let data_word_size = ((input.len() + 31) / 32).into();
        let gas = BASE_COST + data_word_size * COST_PER_WORD;

        return Result::Ok((gas, input));
    }
}

#[cfg(test)]
mod tests {
    use core::result::ResultTrait;
    use crate::eth_call::evm::precompiles::identity::Identity;

    // source:
    // <https://www.evm.codes/playground?unit=Wei&codeType=Mnemonic&code='wFirsWplaceqparameters%20in%20memorybFFjdata~0vMSTOREvvwDoqcall~1QX3FQ_1YX1FY_4jaddressZ4%200xFFFFFFFFjgasvSTATICCALLvvwPutqresulWalonVonqstackvPOPb20vMLOAD'~Z1j//%20v%5Cnq%20thVj%20wb~0x_Offset~ZvPUSHYjargsXSizebWt%20Ve%20Qjret%01QVWXYZ_bjqvw~_>
    #[test]
    fn test_identity_precompile() {
        let calldata = [0x2A].span();

        let (gas, result) = Identity::exec(calldata).unwrap();

        assert_eq!(calldata, result);
        assert_eq!(gas, 18);
    }
}
