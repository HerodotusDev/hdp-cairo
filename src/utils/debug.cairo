from src.types import ChainInfo, TrieNode, TrieNodeBinary, TrieNodeEdge
from starkware.cairo.common.uint256 import Uint256

func print_felt(value: felt) {
    %{ print(f"{ids.value}") %}

    return ();
}

func print_felt_hex(value: felt) {
    %{ print(f"{hex(ids.value)}") %}

    return ();
}

func print_string(value: felt) {
    %{ print(f"String: {ids.value}") %}

    return ();
}
