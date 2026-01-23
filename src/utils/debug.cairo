// ============================================================================
// Debug Helpers
// ============================================================================
// Utility print functions for local debugging in Cairo0.
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
