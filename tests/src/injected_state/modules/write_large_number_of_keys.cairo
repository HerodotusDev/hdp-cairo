#[starknet::contract]
mod write_large_number_of_keys {
    use hdp_cairo::HDP;
    use hdp_cairo::injected_state::state::{InjectedStateMemorizerImpl, InjectedStateMemorizerTrait};

    #[storage]
    struct Storage {}

    #[external(v0)]
    pub fn main(ref self: ContractState, hdp: HDP) -> Array<felt252> {
        // Test parameters matching the Rust test
        let label = 'large_number_keys';

        // Test writing a large number of unique keys
        // Using a smaller number for Cairo due to gas constraints
        let _key_count = 20; // Reduced from 200 for Cairo
        let mut current_root = 0x0;

        // Write keys 0-19 explicitly
        let key0 = 0;
        let value0 = 1000;
        let new_root = hdp.injected_state.write_key(label, key0, value0);
        let read_value = hdp.injected_state.read_key(label, key0).unwrap();
        assert!(read_value == value0, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key1 = 1;
        let value1 = 1001;
        let new_root = hdp.injected_state.write_key(label, key1, value1);
        let read_value = hdp.injected_state.read_key(label, key1).unwrap();
        assert!(read_value == value1, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key2 = 2;
        let value2 = 1002;
        let new_root = hdp.injected_state.write_key(label, key2, value2);
        let read_value = hdp.injected_state.read_key(label, key2).unwrap();
        assert!(read_value == value2, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key3 = 3;
        let value3 = 1003;
        let new_root = hdp.injected_state.write_key(label, key3, value3);
        let read_value = hdp.injected_state.read_key(label, key3).unwrap();
        assert!(read_value == value3, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key4 = 4;
        let value4 = 1004;
        let new_root = hdp.injected_state.write_key(label, key4, value4);
        let read_value = hdp.injected_state.read_key(label, key4).unwrap();
        assert!(read_value == value4, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key5 = 5;
        let value5 = 1005;
        let new_root = hdp.injected_state.write_key(label, key5, value5);
        let read_value = hdp.injected_state.read_key(label, key5).unwrap();
        assert!(read_value == value5, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key6 = 6;
        let value6 = 1006;
        let new_root = hdp.injected_state.write_key(label, key6, value6);
        let read_value = hdp.injected_state.read_key(label, key6).unwrap();
        assert!(read_value == value6, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key7 = 7;
        let value7 = 1007;
        let new_root = hdp.injected_state.write_key(label, key7, value7);
        let read_value = hdp.injected_state.read_key(label, key7).unwrap();
        assert!(read_value == value7, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key8 = 8;
        let value8 = 1008;
        let new_root = hdp.injected_state.write_key(label, key8, value8);
        let read_value = hdp.injected_state.read_key(label, key8).unwrap();
        assert!(read_value == value8, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key9 = 9;
        let value9 = 1009;
        let new_root = hdp.injected_state.write_key(label, key9, value9);
        let read_value = hdp.injected_state.read_key(label, key9).unwrap();
        assert!(read_value == value9, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key10 = 10;
        let value10 = 1010;
        let new_root = hdp.injected_state.write_key(label, key10, value10);
        let read_value = hdp.injected_state.read_key(label, key10).unwrap();
        assert!(read_value == value10, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key11 = 11;
        let value11 = 1011;
        let new_root = hdp.injected_state.write_key(label, key11, value11);
        let read_value = hdp.injected_state.read_key(label, key11).unwrap();
        assert!(read_value == value11, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key12 = 12;
        let value12 = 1012;
        let new_root = hdp.injected_state.write_key(label, key12, value12);
        let read_value = hdp.injected_state.read_key(label, key12).unwrap();
        assert!(read_value == value12, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key13 = 13;
        let value13 = 1013;
        let new_root = hdp.injected_state.write_key(label, key13, value13);
        let read_value = hdp.injected_state.read_key(label, key13).unwrap();
        assert!(read_value == value13, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key14 = 14;
        let value14 = 1014;
        let new_root = hdp.injected_state.write_key(label, key14, value14);
        let read_value = hdp.injected_state.read_key(label, key14).unwrap();
        assert!(read_value == value14, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key15 = 15;
        let value15 = 1015;
        let new_root = hdp.injected_state.write_key(label, key15, value15);
        let read_value = hdp.injected_state.read_key(label, key15).unwrap();
        assert!(read_value == value15, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key16 = 16;
        let value16 = 1016;
        let new_root = hdp.injected_state.write_key(label, key16, value16);
        let read_value = hdp.injected_state.read_key(label, key16).unwrap();
        assert!(read_value == value16, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key17 = 17;
        let value17 = 1017;
        let new_root = hdp.injected_state.write_key(label, key17, value17);
        let read_value = hdp.injected_state.read_key(label, key17).unwrap();
        assert!(read_value == value17, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key18 = 18;
        let value18 = 1018;
        let new_root = hdp.injected_state.write_key(label, key18, value18);
        let read_value = hdp.injected_state.read_key(label, key18).unwrap();
        assert!(read_value == value18, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        let key19 = 19;
        let value19 = 1019;
        let new_root = hdp.injected_state.write_key(label, key19, value19);
        let read_value = hdp.injected_state.read_key(label, key19).unwrap();
        assert!(read_value == value19, "Value should match after write");
        assert!(new_root != current_root, "Writing key should change root");
        current_root = new_root;

        // Verify a sample of the written values
        let sample_key1 = 0;
        let expected_value1 = 1000;
        let read_value1 = hdp.injected_state.read_key(label, sample_key1).unwrap();
        assert!(read_value1 == expected_value1, "Key 0 should have value 1000");

        let sample_key2 = 5;
        let expected_value2 = 1005;
        let read_value2 = hdp.injected_state.read_key(label, sample_key2).unwrap();
        assert!(read_value2 == expected_value2, "Key 5 should have value 1005");

        let sample_key3 = 10;
        let expected_value3 = 1010;
        let read_value3 = hdp.injected_state.read_key(label, sample_key3).unwrap();
        assert!(read_value3 == expected_value3, "Key 10 should have value 1010");

        let sample_key4 = 15;
        let expected_value4 = 1015;
        let read_value4 = hdp.injected_state.read_key(label, sample_key4).unwrap();
        assert!(read_value4 == expected_value4, "Key 15 should have value 1015");

        let sample_key5 = 19;
        let expected_value5 = 1019;
        let read_value5 = hdp.injected_state.read_key(label, sample_key5).unwrap();
        assert!(read_value5 == expected_value5, "Key 19 should have value 1019");

        array![current_root, read_value1, read_value2, read_value3, read_value4, read_value5]
    }
}
