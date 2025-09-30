mod multi_mm_withdrawals_inefficient_dict;

#[starknet::contract]
mod module {
    use hdp_cairo::{
        HDP,
        evm::storage::{StorageTrait, StorageKey, StorageImpl},
    };
    use core::{
        integer::{u256}
    };
    
    use alexandria_bytes::byte_array_ext::{ByteArrayTraitExt};
    use core::byte_array::ByteArrayImpl;

    use super::multi_mm_withdrawals_inefficient_dict::{MultiMMWithdrawalDictTrait, OrdersWithdrawals, BalanceToWithdraw};

    #[derive(Serde, Copy, Drop)]
    struct OrderData {
        fulfillment_keccak_hash: u256,
    }

    #[derive(Serde, Drop)]
    struct FulfillmentCheckResult {
        all_orders_fulfilled: bool,
        lowest_expiration_timestamp: u256,
        orders_withdrawals: Array<OrdersWithdrawals>,
    }

    #[derive(Serde, Copy, Drop)]
    struct OrderFulfillmentDetails {
        order_id: u256,
        escrow_contract_address: u256,
        usr_src_address: u256,
        usr_dst_address: u256,
        expiration_timestamp: u256,
        source_token: u256,
        source_amount: u256,
        destination_token: u256,
        destination_amount: u256,
        source_chain_id: u256,
        destination_chain_id: u256,
        market_maker_withdrawal_address: u256 // This address is also included in fulfillment call on payment registry
    }

    #[storage]
    struct Storage {}

    const FULFILLMENTS_MAPPING_SLOT: u256 = 2; // Retrieved from PaymentRegistry storage layout

    #[external(v0)]
    pub fn main(
        ref self: ContractState,
        hdp: HDP,
        // Public input
        destination_chain_id: felt252,
        payment_registry_address: felt252,
        block_number: u32,
        mut orders_hashes: Array<u256>,
        // Private input
        mut orders_details: Array<OrderFulfillmentDetails>, // These orders details array are provided only offchain
    ) -> FulfillmentCheckResult {
        let mut tmp_is_verified_correctly: bool = true;

        //let mut withdrawals_dict = MultiMMWithdrawalDictTrait::create();
        let mut withdrawals_dict = MultiMMWithdrawalDictTrait::create();

        // Assert arrays have the same length
        let orders_hashes_len = orders_hashes.len();
        let orders_details_len = orders_details.clone().len();
        assert(orders_hashes_len == orders_details_len, 'Mismatched order array lengths');

        let mut current_lowest_expiration_timestamp: u256 = 0;

        let mut i = 0;
        for order in orders_details {

                let mut order_hash = calculate_order_hash(order);

                // Calculate storage slot address on EVM
                let mut bytes: ByteArray = ByteArrayTraitExt::new(0, array![]);

                bytes.append_u256(order_hash);
                bytes.append_u256(FULFILLMENTS_MAPPING_SLOT);

                let mut slot = bytes.keccak_be();

                println!(
                            "Order hash: {:x}",
                            order_hash,
                );

                println!(
                            "Slot: {:x}",
                            slot,
                );

                assert(order_hash == *orders_hashes.at(i), 'Mismatched order hash');

                let mut mm_withdrawal_address_from_slot = 0;

                mm_withdrawal_address_from_slot = hdp
                        .evm
                        .storage_get_slot(
                            @StorageKey {
                                chain_id: destination_chain_id,
                                block_number: block_number.into(),
                                address: payment_registry_address,
                                storage_slot: slot,
                            },
                );


                // let mm_withdrawal_address_from_slot = u256_from_words(storage_slot_value_low, storage_slot_value_high)
                // If slot is 0 it means that order is not fulfilled or market maker dont set any withdrawal address
                if (mm_withdrawal_address_from_slot == 0) {
                    println!(
                        "Order fulfilment verification failure for order {:x}",
                        order_hash,
                    );
                    tmp_is_verified_correctly = false;
                } else {
                    // Sanity check only
                    //assert(mm_withdrawal_address_from_slot == order.market_maker_withdrawal_address, 'Withdrawal address different');

                    if (mm_withdrawal_address_from_slot != order.market_maker_withdrawal_address) {
                        println!(
                            "Withdrawal address different {:x}",
                            order.market_maker_withdrawal_address,
                        );
                    }

                    println!(
                        "Order {:x} fulfilment verified, MM withdrawal address: {:x}",
                        order_hash, mm_withdrawal_address_from_slot
                    );

                    if (i == 0) {
                        current_lowest_expiration_timestamp = order.expiration_timestamp;
                    } else if (order.expiration_timestamp < current_lowest_expiration_timestamp) {
                        current_lowest_expiration_timestamp = order.expiration_timestamp;
                    }

                     withdrawals_dict.add(
                             mm_withdrawal_address_from_slot,
                             order.source_token,
                             order.source_amount
                     );
                }
                i += 1;
        };

        let orders_withdrawals_array = withdrawals_dict.build_all_withdrawals();


         FulfillmentCheckResult {
                 all_orders_fulfilled: tmp_is_verified_correctly,
                 lowest_expiration_timestamp: current_lowest_expiration_timestamp,
                 orders_withdrawals: orders_withdrawals_array
         }
    }

    fn calculate_order_hash(
            order_details: OrderFulfillmentDetails
    ) -> u256 {
            let mut bytes: ByteArray = ByteArrayTraitExt::new(0, array![]);

            bytes.append_u256(order_details.order_id);
            bytes.append_u256(order_details.escrow_contract_address);
            bytes.append_u256(order_details.usr_src_address);
            bytes.append_u256(order_details.usr_dst_address);
            bytes.append_u256(order_details.expiration_timestamp);
            bytes.append_u256(order_details.source_token);
            bytes.append_u256(order_details.source_amount);
            bytes.append_u256(order_details.destination_token);
            bytes.append_u256(order_details.destination_amount);
            bytes.append_u256(order_details.source_chain_id);
            bytes.append_u256(order_details.destination_chain_id);


            let order_hash_calculated = bytes.keccak_be();
            order_hash_calculated
    }


    // TESTS ///
    fn get_sample_orders_withdrawals() -> Array<OrdersWithdrawals> {
        // Create a mutable array to hold all the withdrawal orders.
        let mut all_withdrawals = array![];

        // --- 1. First Market Maker Withdrawal ---

        // Create an array for the first market maker's balances.
        let mut ow1_balances = array![];

        // Append the first balance (WETH).
        ow1_balances.append(BalanceToWithdraw {
            token_contract_address: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2_u256,
            amount: 1_000_000_000_000_000_000_u256, // 1e18
        });
        // Append the second balance (DAI).
        ow1_balances.append(BalanceToWithdraw {
            token_contract_address: 0x6B175474E89094C44Da98b954EedeAC495271d0F_u256,
            amount: 500_000_000_000_000_000_000_u256, // 500 * 1e18
        });

        // Create the first OrdersWithdrawals struct.
        let ow1 = OrdersWithdrawals {
            market_maker_withdrawal_address: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8_u256,
            balances_to_withdraw: ow1_balances,
        };
        all_withdrawals.append(ow1);

        // --- 2. Second Market Maker Withdrawal ---

        // Create an array for the second market maker's balance.
        let mut ow2_balances = array![];

        // Append the single balance (USDC).
        ow2_balances.append(BalanceToWithdraw {
            token_contract_address: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48_u256,
            amount: 2_500_000_000_u256, // 2500 * 1e6
        });

        // Create the second OrdersWithdrawals struct.
        let ow2 = OrdersWithdrawals {
            market_maker_withdrawal_address: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC_u256,
            balances_to_withdraw: ow2_balances,
        };
        all_withdrawals.append(ow2);

        // Return the final array containing all withdrawal orders.
        all_withdrawals
    }
}
