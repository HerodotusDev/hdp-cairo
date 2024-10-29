from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin, KeccakBuiltin, PoseidonBuiltin

from src.types import ChainInfo
from src.decoders.evm.account_decoder import AccountDecoder, AccountField

func test_account_decoding{range_check_ptr, bitwise_ptr: BitwiseBuiltin*, pow2_array: felt*}(
    accounts: felt, index: felt
) {
    alloc_locals;

    if (accounts == index) {
        return ();
    }

    let (rlp) = alloc();

    local block_number: felt;
    %{
        import os
        from dotenv import load_dotenv
        from tools.py.providers.evm.provider import EvmProvider
        from tools.py.types.evm.account import FeltAccount, Account
        from tools.py.utils import (
            bytes_to_8_bytes_chunks_little,
        )

        load_dotenv()
        RPC_URL_MAINNET = os.getenv("RPC_URL_MAINNET")
        if RPC_URL_MAINNET is None:
            raise ValueError("RPC_URL_MAINNET environment variable is not set")
        provider = EvmProvider(RPC_URL_MAINNET, 1)
        rpc_account = provider.get_rpc_account_by_address(account_array[ids.index]["address"], account_array[ids.index]["block_number"])
        account = Account.from_rpc_data(rpc_account)
        felt_account = FeltAccount(account)

        segments.write_arg(ids.rlp, bytes_to_8_bytes_chunks_little(account.raw_rlp()))
    %}

    let nonce = AccountDecoder.get_field(rlp, AccountField.NONCE);
    %{
        low, high = felt_account.nonce()
        assert ids.nonce.low == low
        assert ids.nonce.high == high
    %}

    let balance = AccountDecoder.get_field(rlp, AccountField.BALANCE);
    %{
        low, high = felt_account.balance()
        assert ids.balance.low == low
        assert ids.balance.high == high
    %}

    let state_root = AccountDecoder.get_field(rlp, AccountField.STATE_ROOT);
    %{
        low, high = felt_account.storage_hash()
        assert ids.state_root.low == low
        assert ids.state_root.high == high
    %}

    let code_hash = AccountDecoder.get_field(rlp, AccountField.CODE_HASH);
    %{
        low, high = felt_account.code_hash()
        assert ids.code_hash.low == low
        assert ids.code_hash.high == high
    %}

    return test_account_decoding(accounts, index + 1);
}
