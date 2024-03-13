### Fixtures Generation:

cargo run -- encode -a -c storage_avg.json "avg" -b 5382810 5382815 "storage.0x75CeC1db9dCeb703200EAa6595f66885C962B920.0x0000000000000000000000000000000000000000000000000000000000000002" && \
cargo run -- encode -a -c storage_sum.json "sum" -b 5382810 5382815 "storage.0x75CeC1db9dCeb703200EAa6595f66885C962B920.0x0000000000000000000000000000000000000000000000000000000000000002" && \
cargo run -- encode -a -c account_nonce_sum.json "sum" -b 4952100 4952120 "account.0x7f2c6f930306d3aa736b3a6c6a98f512f74036d4.nonce" && \
cargo run -- encode -a -c account_balance_avg.json "avg" -b 4952100 4952120 "account.0x7f2c6f930306d3aa736b3a6c6a98f512f74036d4.balance"