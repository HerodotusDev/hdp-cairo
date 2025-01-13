use strum_macros::FromRepr;
use starknet_types_rpc::BlockHeader;

pub struct CairoHeader;


#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Parent = 0
}