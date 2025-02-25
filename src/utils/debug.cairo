from starkware.cairo.common.cairo_builtins import UInt384

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

func print_uint384(value: UInt384) {
    %{ print(f"{hex(ids.value.d3 * 2 ** 144 + ids.value.d2 * 2 ** 96 + ids.value.d1 * 2 ** 48 + ids.value.d0)}") %}

    return ();
}

