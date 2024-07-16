# Takes a 64 bit word in little endian, returns the byte at a given position as it would be in big endian.
# Ie: word = b7 b6 b5 b4 b3 b2 b1 b0
# returns bi such that i = byte_position
def extract_byte_at_pos(word_64_little: int, byte_position: int):
    extracted_byte_at_pos = (word_64_little & (0xFF << (8 * byte_position))) >> (
        8 * byte_position
    )
    return extracted_byte_at_pos


def decode_long_value_len(word_64_little: int, item_starts_at_byte: int, len_len: int):
    value_len = 0
    for i in range(len_len):
        byte = extract_byte_at_pos(word_64_little, item_starts_at_byte + i)
        value_len = (value_len << 8) + byte
    return value_len


def get_rlp_len(rlp: int, item_start_offset: int):
    current_item = extract_byte_at_pos(rlp, item_start_offset)

    if current_item <= 0x7F:
        item_type = 0  # single byte
    elif 0x80 <= current_item <= 0xB6:
        item_type = 1  # short string
    elif 0xB7 <= current_item <= 0xBF:
        item_type = 2  # long string
    elif 0xC0 <= current_item <= 0xF6:
        item_type = 3  # short list
    elif 0xF7 <= current_item <= 0xFF:
        item_type = 4  # long list
    else:
        raise ValueError("Invalid RLP item")

    # Single Byte
    if item_type == 0:
        return 1

    # Short String
    if item_type == 1:
        current_value_len = current_item - 0x80
        return current_value_len + 1

    # Long String
    if item_type == 2:
        len_len = current_item - 0xB7
        value_len = decode_long_value_len(rlp, item_start_offset + 1, len_len)
        return value_len + len_len + 1

    # Short List
    if item_type == 3:
        current_value_len = current_item - 0xC0
        return current_value_len + 1

    # Long List
    if item_type == 4:
        len_len = current_item - 0xF7
        item_len = decode_long_value_len(rlp, item_start_offset + 1, len_len)
        return item_len + len_len + 1
