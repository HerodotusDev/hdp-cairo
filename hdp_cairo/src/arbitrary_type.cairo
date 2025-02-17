use starknet::SyscallResultTrait;
use starknet::syscalls::call_contract_syscall;

const ARBITRARY_TYPE_CONTRACT_ADDRESS: felt252 = 'arbitrary_type';

pub fn arbitrary_type<S, +core::serde::Serde<S>, +Drop<S>, D, +core::serde::Serde<D>>(obj: S) -> D {
    let mut obj_serialized = array![];
    obj.serialize(ref obj_serialized);

    let mut ret = call_contract_syscall(
        ARBITRARY_TYPE_CONTRACT_ADDRESS.try_into().unwrap(), 0, obj_serialized.span(),
    )
        .unwrap_syscall();

    Serde::<D>::deserialize(ref ret).unwrap()
}
