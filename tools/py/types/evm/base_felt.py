from typing import Union, Tuple
from hexbytes import HexBytes


class BaseFelt:
    def _split_word_to_felt(
        self, value: Union[int, bytes, HexBytes], as_le: bool = False
    ) -> Tuple[int, int]:
        if isinstance(value, int):
            value = value.to_bytes(32, "big")
        elif isinstance(value, (bytes, HexBytes)):
            value = value.rjust(32, b"\x00")

        if as_le:
            value = value[::-1]  # Reverse byte order for LE conversion

        int_value = int.from_bytes(
            value, "big"
        )  # Always interpret bytes as big-endian now

        lower_part = int_value & ((1 << 128) - 1)  # Lower 128 bits
        upper_part = int_value >> 128  # Upper 128 bits

        return (lower_part, upper_part)
