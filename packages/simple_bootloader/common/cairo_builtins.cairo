from common.poseidon_state import PoseidonBuiltinState

// Specifies the hash builtin memory structure.
struct HashBuiltin {
    x: felt,
    y: felt,
    result: felt,
}

// Specifies the bitwise builtin memory structure.
struct BitwiseBuiltin {
    x: felt,
    y: felt,
    x_and_y: felt,
    x_xor_y: felt,
    x_or_y: felt,
}

// Specifies the Poseidon builtin memory structure.
struct PoseidonBuiltin {
    input: PoseidonBuiltinState,
    output: PoseidonBuiltinState,
}