%builtins range_check bitwise
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256, uint256_reverse_endian

from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from src.hdp.decoders.account_decoder import AccountDecoder, ACCOUNT_FIELD
from src.libs.utils import pow2alloc128

func main{
    range_check_ptr,
    bitwise_ptr: BitwiseBuiltin*
}() {
    alloc_locals;
    let pow2_array: felt* = pow2alloc128();

    let (account_one: felt*) = alloc();
    let (account_two: felt*) = alloc();
    %{
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )
        account_one_bytes = bytes.fromhex("f8440180a0b08d8d9b22ac1cc11aa964f398cab09d79a498de101033ee0d82b406e7622e20a0cafbd9135200b24454a9ffcac5a8db40947a17f8a8a542062d0f1fb48bd8b269")
        account_one_chunks = bytes_to_8_bytes_chunks_little(account_one_bytes)

        account_two_bytes = bytes.fromhex("f84c358820e9ce1cd62eef86a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
        account_two_chunks = bytes_to_8_bytes_chunks_little(account_two_bytes)

        segments.write_arg(ids.account_one, account_one_chunks)
        segments.write_arg(ids.account_two, account_two_chunks)
    %}
    
    // ACCOUNT ONE
    let nonce_le = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_one, field=ACCOUNT_FIELD.NONCE);
    let (nonce) = uint256_reverse_endian(nonce_le);

    assert nonce.low = 1;
    assert nonce.high = 0;

    let balance_le = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_one, field=ACCOUNT_FIELD.BALANCE);

    let (balance) = uint256_reverse_endian(balance_le);
    assert balance.low = 0;
    assert balance.high = 0;

    let state_root = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_one, field=ACCOUNT_FIELD.STATE_ROOT);

    assert state_root.low = 0x9DB0CA98F364A91AC11CAC229B8D8DB0;
    assert state_root.high = 0x202E62E706B4820DEE331010DE98A479;

    let code_hash = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_one, field=ACCOUNT_FIELD.CODE_HASH);

    assert code_hash.low = 0x40DBA8C5CAFFA95444B2005213D9FBCA;
    assert code_hash.high = 0x69B2D88BB41F0F2D0642A5A8F8177A94;

    // ACCOUNT TWO
    let nonce_le = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_two, field=ACCOUNT_FIELD.NONCE);
    let (nonce) = uint256_reverse_endian(nonce_le);

    assert nonce.low = 0x35;
    assert nonce.high = 0;

    let balance_le = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_two, field=ACCOUNT_FIELD.BALANCE);
    let (balance) = uint256_reverse_endian(balance_le);

    assert balance.low = 0x20e9ce1cd62eef86;
    assert balance.high = 0;

    let state_root = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_two, field=ACCOUNT_FIELD.STATE_ROOT);

    assert state_root.low = 0x6EF8C092E64583FFA655CC1B171FE856;
    assert state_root.high = 0x21B463E3B52F6201C0AD6C991BE0485B;

    let code_hash = AccountDecoder.get_field{
        range_check_ptr=range_check_ptr,
        bitwise_ptr=bitwise_ptr,
        pow2_array=pow2_array,
    }(rlp=account_two, field=ACCOUNT_FIELD.CODE_HASH);

    assert code_hash.low = 0xC003C7DCB27D7E923C23F7860146D2C5;
    assert code_hash.high = 0x70A4855D04D8FA7B3B2782CA53B600E5;
    

    return ();
}

