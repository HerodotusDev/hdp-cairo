use strum_macros::FromRepr;

pub struct CairoStarknetHeader;

#[derive(FromRepr, Debug)]
pub enum FunctionId {
    Parent = 0
}