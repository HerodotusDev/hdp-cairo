struct ChainInfo {
    id: felt,
    id_bytes_len: felt,
    byzantium: felt,
    layout: felt,
}

struct MMRMeta {
    id: felt,
    root: felt,
    size: felt,
    chain_id: felt,
}

struct ModuleTask {
    program_hash: felt,
    module_inputs_len: felt,
    module_inputs: felt*,
}
