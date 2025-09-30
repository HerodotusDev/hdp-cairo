use core::{
    integer::u256,
    array::ArrayTrait,
    option::{Option},
};

// -- Data structures --

#[derive(Serde, Drop, Copy)]
pub struct BalanceToWithdraw {
    pub token_contract_address: u256,
    pub amount: u256,
}

#[derive(Serde, Drop)]
pub struct OrdersWithdrawals {
    pub market_maker_withdrawal_address: u256,
    pub balances_to_withdraw: Array<BalanceToWithdraw>,
}

#[derive(Drop)]
pub struct MultiMMWithdrawalDict {
    pub mm_keys: Array<u256>,
    pub token_keys: Array<u256>,
    pub balances: Array<u256>,
}

// -- Trait declaration --

pub trait MultiMMWithdrawalDictTrait {
    fn create() -> MultiMMWithdrawalDict;
    fn add(ref self: MultiMMWithdrawalDict, mm_withdrawal_address: u256, token_address: u256, value: u256);
    fn get(ref self: MultiMMWithdrawalDict, mm_withdrawal_address: u256, token_address: u256) -> Option<u256>;
    fn build_all_withdrawals(ref self: MultiMMWithdrawalDict) -> Array<OrdersWithdrawals>;
}

// -- Implementation --

impl MultiMMWithdrawalDictImpl of MultiMMWithdrawalDictTrait {
    fn create() -> MultiMMWithdrawalDict {
        MultiMMWithdrawalDict {
            mm_keys: ArrayTrait::new(),
            token_keys: ArrayTrait::new(),
            balances: ArrayTrait::new(),
        }
    }

    fn add(ref self: MultiMMWithdrawalDict, mm_withdrawal_address: u256, token_address: u256, value: u256) {
        let mut i = 0;
        let len = self.mm_keys.len();
        let mut found = false;

        // Temporary arrays to rebuild state
        let mut new_mm_keys = ArrayTrait::new();
        let mut new_token_keys = ArrayTrait::new();
        let mut new_balances = ArrayTrait::new();

        loop {
            if i >= len { break; }

            let existing_mm = *self.mm_keys.at(i);
            let existing_token = *self.token_keys.at(i);
            let existing_balance = *self.balances.at(i);

            if existing_mm == mm_withdrawal_address && existing_token == token_address {
                // Update the balance
                new_mm_keys.append(existing_mm);
                new_token_keys.append(existing_token);
                new_balances.append(existing_balance + value);
                found = true;
            } else {
                // Keep existing entry
                new_mm_keys.append(existing_mm);
                new_token_keys.append(existing_token);
                new_balances.append(existing_balance);
            }
            i += 1;
        }

        if !found {
            // New entry
            new_mm_keys.append(mm_withdrawal_address);
            new_token_keys.append(token_address);
            new_balances.append(value);
        }

        // Replace the old arrays with the new ones
        self.mm_keys = new_mm_keys;
        self.token_keys = new_token_keys;
        self.balances = new_balances;
    }


    fn get(ref self: MultiMMWithdrawalDict, mm_withdrawal_address: u256, token_address: u256) -> Option<u256> {
        let mut i = 0;
        loop {
            if i >= self.mm_keys.len() { break; }
            if *self.mm_keys.at(i) == mm_withdrawal_address && *self.token_keys.at(i) == token_address {
                return Option::Some(*self.balances.at(i));
            }
            i += 1;
        };
        Option::None
    }

    fn build_all_withdrawals(ref self: MultiMMWithdrawalDict) -> Array<OrdersWithdrawals> {
        let mut all_withdrawals = ArrayTrait::new();
        let mut processed_mms = ArrayTrait::new();

        let mut i = 0;
        loop {
            if i >= self.mm_keys.len() { break; }

            let mm = *self.mm_keys.at(i);

            // Check if this MM has already been processed
            let mut skip = false;
            let mut j = 0;
            loop {
                if j >= processed_mms.len() { break; }
                if *processed_mms.at(j) == mm {
                    skip = true;
                    break;
                }
                j += 1;
            }

            if skip {
                i += 1;
                continue;
            }

            processed_mms.append(mm);

            let mut balances_to_withdraw = ArrayTrait::new();
            let mut k = 0;
            loop {
                if k >= self.mm_keys.len() { break; }
                if *self.mm_keys.at(k) == mm {
                    balances_to_withdraw.append(BalanceToWithdraw {
                        token_contract_address: *self.token_keys.at(k),
                        amount: *self.balances.at(k),
                    });
                    println!("MM {:?} withdrawal amount of: {:?} token: {:?}", mm, *self.balances.at(k), *self.token_keys.at(k));

                }
                k += 1;
            }

            all_withdrawals.append(OrdersWithdrawals {
                market_maker_withdrawal_address: mm,
                balances_to_withdraw,
            });

            i += 1;
        }

        all_withdrawals
    }
}
