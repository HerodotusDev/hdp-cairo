from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_builtins import PoseidonBuiltin
from starkware.cairo.common.builtin_poseidon.poseidon import poseidon_hash_many
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.alloc import alloc
from src.memorizers.bare import BareMemorizer

namespace EvmPackParams {
    const HEADER_PARAMS_LEN = 2;
    func header(chain_id: felt, block_number: felt) -> (params: felt*, params_len: felt) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;

        return (params=params, params_len=2);
    }

    const ACCOUNT_PARAMS_LEN = 3;
    func account(chain_id: felt, block_number: felt, address: felt) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;

        return (params=params, params_len=3);
    }

    const STORAGE_PARAMS_LEN = 5;
    func storage(chain_id: felt, block_number: felt, address: felt, storage_slot: Uint256) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = block_number;
        assert params[2] = address;
        assert params[3] = storage_slot.high;
        assert params[4] = storage_slot.low;

        return (params=params, params_len=5);
    }

    const BLOCK_TX_LABEL = 'block_tx';
    const BLOCK_TX_PARAMS_LEN = 4;
    func block_tx(chain_id: felt, block_number: felt, index: felt) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = BLOCK_TX_LABEL;
        assert params[2] = block_number;
        assert params[3] = index;

        return (params=params, params_len=4);
    }

    const BLOCK_RECEIPT_LABEL = 'block_receipt';
    const BLOCK_RECEIPT_PARAMS_LEN = 4;
    func block_receipt(chain_id: felt, block_number: felt, index: felt) -> (
        params: felt*, params_len: felt
    ) {
        alloc_locals;

        local params: felt* = nondet %{ segments.add() %};
        assert params[0] = chain_id;
        assert params[1] = BLOCK_RECEIPT_LABEL;
        assert params[2] = block_number;
        assert params[3] = index;

        return (params=params, params_len=4);
    }
}

namespace EvmHashParams {
    func header{poseidon_ptr: PoseidonBuiltin*}(chain_id: felt, block_number: felt) -> felt {
        let (params, params_len) = EvmPackParams.header(
            chain_id=chain_id, block_number=block_number
        );
        return hash_memorizer_key(params, params_len);
    }

    func account{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt
    ) -> felt {
        let (params, params_len) = EvmPackParams.account(
            chain_id=chain_id, block_number=block_number, address=address
        );
        return hash_memorizer_key(params, params_len);
    }

    func storage{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, address: felt, storage_slot: Uint256
    ) -> felt {
        let (params, params_len) = EvmPackParams.storage(
            chain_id=chain_id, block_number=block_number, address=address, storage_slot=storage_slot
        );
        return hash_memorizer_key(params, params_len);
    }

    func block_tx{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, index: felt
    ) -> felt {
        let (params, params_len) = EvmPackParams.block_tx(
            chain_id=chain_id, block_number=block_number, index=index
        );
        return hash_memorizer_key(params, params_len);
    }

    func block_receipt{poseidon_ptr: PoseidonBuiltin*}(
        chain_id: felt, block_number: felt, index: felt
    ) -> felt {
        let (params, params_len) = EvmPackParams.block_receipt(
            chain_id=chain_id, block_number=block_number, index=index
        );
        return hash_memorizer_key(params, params_len);
    }
}

namespace EvmHashParams2 {
    func header{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, EvmPackParams.HEADER_PARAMS_LEN);
    }

    func account{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, EvmPackParams.ACCOUNT_PARAMS_LEN);
    }

    func storage{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, EvmPackParams.STORAGE_PARAMS_LEN);
    }

    func block_tx{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, EvmPackParams.BLOCK_TX_PARAMS_LEN);
    }

    func block_receipt{poseidon_ptr: PoseidonBuiltin*}(params: felt*) -> felt {
        return hash_memorizer_key(params, EvmPackParams.BLOCK_RECEIPT_PARAMS_LEN);
    }
}

func hash_memorizer_key{poseidon_ptr: PoseidonBuiltin*}(params: felt*, params_len: felt) -> felt {
    let (res) = poseidon_hash_many(params_len, params);
    return res;
}

namespace EvmMemorizer {
    func init() -> (dict_ptr: DictAccess*, dict_ptr_start: DictAccess*) {
        alloc_locals;
        return BareMemorizer.init();
    }

    func add{evm_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt, data: felt*) {
        BareMemorizer.add{dict_ptr=evm_memorizer}(key, data);

        return ();
    }

    func get{evm_memorizer: DictAccess*, poseidon_ptr: PoseidonBuiltin*}(key: felt) -> (
        rlp: felt*
    ) {
        let (rlp) = BareMemorizer.get{dict_ptr=evm_memorizer}(key);
        return (rlp=rlp);
    }
}
