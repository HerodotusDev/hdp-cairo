#[derive(Serde, Drop)]
pub enum ChainId {
    EthereumMainnet,
    EthereumSepolia,
    StarknetMainnet,
    StarknetSepolia,
}

pub trait ChainIdTrait {
    fn from_str(val: felt252) -> Option<ChainId>;
    fn as_felt(self: ChainId) -> felt252;
}

impl ChainIdImpl of ChainIdTrait {
    fn from_str(val: felt252) -> Option<ChainId> {
        if val == 'Ethereum_Mainnet' {
            return Option::Some(ChainId::EthereumMainnet);
        } else if val == 'Ethereum_Sepolia' {
            return Option::Some(ChainId::EthereumSepolia);
        } else if val == 'Starknet_Mainnet' {
            return Option::Some(ChainId::StarknetMainnet);
        } else if val == 'Starknet_Sepolia' {
            return Option::Some(ChainId::StarknetSepolia);
        } else {
            Option::None
        }
    }

    fn as_felt(self: ChainId) -> felt252 {
        match self {
            ChainId::EthereumMainnet => 1,
            ChainId::EthereumSepolia => 11155111,
            ChainId::StarknetMainnet => 23448594291968334,
            ChainId::StarknetSepolia => 393402133025997798000961,
        }
    }
}

impl TryIntoImpl of TryInto<felt252, ChainId> {
    fn try_into(self: felt252) -> Option<ChainId> {
        ChainIdTrait::from_str(self)
    }
}

impl IntoImpl of Into<ChainId, felt252> {
    fn into(self: ChainId) -> felt252 {
        self.as_felt()
    }
}
