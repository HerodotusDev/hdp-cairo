#[starknet::contract]
mod module {
    use core::byte_array::ByteArrayImpl;
    use hdp_cairo::{
        HDP, evm::block_receipt::{BlockReceiptImpl, BlockReceiptKey, BlockReceiptTrait},
    };
    pub mod bloom;
    use bloom::contains;

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        let key = BlockReceiptKey {
            chain_id: 11155111, block_number: 7692344, transaction_index: 183,
        };

        let bloom = hdp.evm.block_receipt_get_bloom(@key);
        print!("bloom {:?}", bloom);

        let mut arr: ByteArray = "";
        arr.append_word((*bloom[0]).into(), 16);
        arr.append_word((*bloom[1]).into(), 16);
        arr.append_word((*bloom[2]).into(), 16);
        arr.append_word((*bloom[3]).into(), 16);
        arr.append_word((*bloom[4]).into(), 16);
        arr.append_word((*bloom[5]).into(), 16);
        arr.append_word((*bloom[6]).into(), 16);
        arr.append_word((*bloom[7]).into(), 16);
        arr.append_word((*bloom[8]).into(), 16);
        arr.append_word((*bloom[9]).into(), 16);
        arr.append_word((*bloom[10]).into(), 16);
        arr.append_word((*bloom[11]).into(), 16);
        arr.append_word((*bloom[12]).into(), 16);
        arr.append_word((*bloom[13]).into(), 16);
        arr.append_word((*bloom[14]).into(), 16);
        arr.append_word((*bloom[15]).into(), 16);

        let b = contains(
            arr,
            u256 {
                low: 0x77782d7a8786f5907f93b0f4702f4f23, high: 0x35d79ab81f2b2017e19afb5c55717788,
            },
        );
        println!("bool: {}", b);

        array![bloom.len().into()]
    }
}
