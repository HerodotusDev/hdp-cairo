struct ChainInfo {
    id: felt,
    id_bytes_len: felt,
    encoded_id: felt,
    encoded_id_bytes_len: felt,
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

// Enum TrieNode
struct TrieNode {
    type: felt,
    field1: felt,
    field2: felt,
    field3: felt,
}
struct TrieNodeBinary {
    type: felt,
    left: felt,
    right: felt,
    _unused: felt,
}
struct TrieNodeEdge {
    type: felt,
    child: felt,
    value: felt,
    len: felt,
}
