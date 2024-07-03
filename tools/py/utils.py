"""Utility functions."""

import json
import os
import shutil
import requests
import sysconfig


def load_json_from_package(resource):
    path = os.path.join(sysconfig.get_path("purelib"), resource)
    with open(path, "r") as file:
        return json.load(file)


def split_128(a):
    """Takes in value, returns uint256-ish tuple."""
    return (a & ((1 << 128) - 1), a >> 128)


def from_uint256(a):
    """Takes in uint256-ish tuple, returns value."""
    return a[0] + (a[1] << 128)


def uint256_reverse_endian(x: int):
    return int.from_bytes(x.to_bytes(32, "big"), "little")


def hex_to_int_array(hex_array):
    return [int(x, 16) for x in hex_array]


def reverse_endian(x: int):
    hex_str = hex(x)[2:]
    if len(hex_str) % 2 != 0:
        hex_str = "0" + hex_str
    return int.from_bytes(bytes.fromhex(hex_str), "little")


def int_get_bytes_len(x: int):
    return (x.bit_length() + 7) // 8


def flatten(t):
    result = []
    for item in t:
        if isinstance(item, (tuple, list)):
            result.extend(flatten(item))
        else:
            result.append(item)
    return result


def reverse_endian_bytes(x: bytes):
    return int.from_bytes(x, "little")


def reverse_and_split_256_bytes(x: bytes):
    return split_128(reverse_endian_bytes(x))


def reverse_endian_256(x: int):
    return int.from_bytes(x.to_bytes(32, "big"), "little")


def parse_int_to_bytes(x: int) -> bytes:
    """
    Convert an integer to a bytes object.
    If the number of bytes is odd, left pad with one leading zero.
    """
    hex_str = hex(x)[2:]
    if len(hex_str) % 2 == 1:
        hex_str = "0" + hex_str
    return bytes.fromhex(hex_str)


def count_trailing_zero_bytes_from_int(number: int) -> int:
    """
    Counts the number of trailing zero bytes in the hexadecimal representation of an integer.

    Args:
    number (int): The integer to analyze.

    Returns:
    int: The number of trailing zero bytes.
    """
    # Convert the integer to a hexadecimal string without the '0x' prefix
    hex_str = format(number, "x")

    # Ensure the hex string length is even for complete byte representation
    if len(hex_str) % 2 != 0:
        hex_str = "0" + hex_str

    # Initialize count of trailing zero bytes
    trailing_zero_bytes = 0

    # Reverse the string to start checking from the last character
    reversed_hex_str = hex_str[::-1]

    # Iterate over each pair of characters in the reversed string
    for i in range(0, len(reversed_hex_str), 2):
        if reversed_hex_str[i : i + 2] == "00":
            trailing_zero_bytes += 1
        else:
            break  # Stop counting at the first non-zero byte

    return trailing_zero_bytes


def count_leading_zero_nibbles_from_hex(hex_str: str) -> int:
    """
    Counts the number of leading zero nibbles in a hexadecimal string.

    Args:
    hex_str (str): The hexadecimal string to analyze.

    Returns:
    int: The number of leading zero nibbles.
    """
    # Remove any leading '0x' if present
    if hex_str.startswith("0x"):
        hex_str = hex_str[2:]

    # Initialize count of leading zero nibbles
    leading_zero_nibbles = 0

    # Iterate over each character in the string
    for char in hex_str:
        if char == "0":
            leading_zero_nibbles += 1
        else:
            break  # Stop counting at the first non-zero nibble

    return leading_zero_nibbles


def rpc_request(url, rpc_request):
    headers = {"Content-Type": "application/json"}
    response = requests.post(url=url, headers=headers, data=json.dumps(rpc_request))
    # print(f"Status code: {response.status_code}")
    # print(f"Response content: {response.content}")
    return response.json()


def bytes_to_8_bytes_chunks_little(input_bytes: bytes):
    # Split the input_bytes into 8-byte chunks
    byte_chunks = [input_bytes[i : i + 8] for i in range(0, len(input_bytes), 8)]
    # Convert each chunk to little-endian integers
    little_endian_ints = [
        int.from_bytes(chunk, byteorder="little") for chunk in byte_chunks
    ]
    return little_endian_ints


def little_8_bytes_chunks_to_bytes(little_endian_ints: list[int], bytes_len: int):
    assert bytes_len >= 0, "bytes_len must be a non-negative integer"
    last_chunk_index = 8 * (len(little_endian_ints) - 1)
    assert (
        bytes_len > last_chunk_index
    ), "bytes_len is not sufficient to hold all integers"
    # Convert each little-endian integer to an 8-byte chunk
    byte_chunks = [
        int.to_bytes(integer, length=8, byteorder="little")
        for integer in little_endian_ints[:-1]
    ]
    byte_chunks.append(
        int.to_bytes(
            little_endian_ints[-1],
            length=bytes_len - last_chunk_index,
            byteorder="little",
        )
    )
    # Concatenate all byte chunks into a single bytes object
    output_bytes = b"".join(byte_chunks)
    return output_bytes


def bytes_to_8_bytes_chunks_big(input_bytes: bytes):
    # Split the input_bytes into 8-byte chunks
    byte_chunks = [input_bytes[i : i + 8] for i in range(0, len(input_bytes), 8)]
    # Convert each chunk to big-endian integers
    big_endian_ints = [int.from_bytes(chunk, byteorder="big") for chunk in byte_chunks]
    return big_endian_ints


def big_8_bytes_chunks_to_bytes(big_endian_ints: list[int], bytes_len: int):
    assert bytes_len >= 0, "bytes_len must be a non-negative integer"
    last_chunk_index = 8 * (len(big_endian_ints) - 1)
    assert (
        bytes_len > last_chunk_index
    ), "bytes_len is not sufficient to hold all integers"
    # Convert each big-endian integer to an 8-byte chunk
    byte_chunks = [
        int.to_bytes(integer, length=8, byteorder="big")
        for integer in big_endian_ints[:-1]
    ]
    byte_chunks.append(
        int.to_bytes(
            big_endian_ints[-1],
            length=bytes_len - last_chunk_index,
            byteorder="big",
        )
    )
    # Concatenate all byte chunks into a single bytes object
    output_bytes = b"".join(byte_chunks)
    return output_bytes


def bytes_to_16_bytes_chunks_big(input_bytes: bytes):
    # Split the input_bytes into 8-byte chunks
    byte_chunks = [input_bytes[i : i + 16] for i in range(0, len(input_bytes), 16)]
    # Convert each chunk to big-endian integers
    big_endian_ints = [int.from_bytes(chunk, byteorder="big") for chunk in byte_chunks]
    return big_endian_ints


def big_16_bytes_chunks_to_bytes(big_endian_ints: list[int], bytes_len: int):
    assert bytes_len >= 0, "bytes_len must be a non-negative integer"
    last_chunk_index = 16 * (len(big_endian_ints) - 1)
    assert (
        bytes_len > last_chunk_index
    ), "bytes_len is not sufficient to hold all integers"
    # Convert each big-endian integer to an 16-byte chunk
    byte_chunks = [
        int.to_bytes(integer, length=16, byteorder="big")
        for integer in big_endian_ints[:-1]
    ]
    byte_chunks.append(
        int.to_bytes(
            big_endian_ints[-1],
            length=bytes_len - last_chunk_index,
            byteorder="big",
        )
    )
    # Concatenate all byte chunks into a single bytes object
    output_bytes = b"".join(byte_chunks)
    return output_bytes


def write_to_json(filename, data):
    """Helper function to write data to a json file"""
    with open(filename, "w") as f:
        json.dump(data, f, indent=4)


def create_directory(path: str):
    if not os.path.exists(path):
        os.makedirs(path)
        print(f"Directory created: {path}")


def clear_directory(path):
    """Delete all files and sub-directories in a directory without deleting the directory itself."""
    for filename in os.listdir(path):
        file_path = os.path.join(path, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            print(f"Failed to delete {file_path}. Reason: {e}")


def get_files_from_folders(folders, ext=".cairo"):
    return [
        os.path.join(folder, f)
        for folder in folders
        for f in os.listdir(folder)
        if os.path.isfile(os.path.join(folder, f)) and f.endswith(ext)
    ]


def validate_initial_params(initial_params: dict):
    assert (
        type(initial_params) == dict
    ), f"initial_params should be a dictionary. Got {type(initial_params)} instead"
    assert set(initial_params) == {
        "mmr_peaks",
        "mmr_size",
        "mmr_roots",
    }, f"initial_params should have keys 'mmr_peaks', 'mmr_size' and 'mmr_roots'. Got {initial_params.keys()} instead"
    assert (
        type(initial_params["mmr_peaks"]) == dict
        and type(initial_params["mmr_roots"]) == dict
        and type(initial_params["mmr_size"]) == int
    ), f"mmr_peaks and mmr_roots should be dictionaries and mmr_size should be an integer. Got {type(initial_params['mmr_peaks'])}, {type(initial_params['mmr_roots'])} and {type(initial_params['mmr_size'])} instead"
    assert set(initial_params["mmr_peaks"].keys()) & set(
        initial_params["mmr_roots"].keys()
    ) == {
        "poseidon",
        "keccak",
    }, f"peaks and mmr_roots should have keys 'poseidon' and 'keccak'. Got {initial_params['mmr_peaks'].keys()} and {initial_params['mmr_roots'].keys()} instead"
    assert type(initial_params["mmr_peaks"]["poseidon"]) == list and type(
        initial_params["mmr_peaks"]["keccak"] == list
    ), f"mmr_peaks['poseidon'] and mmr_peaks['keccak'] should be lists. Got {type(initial_params['mmr_peaks']['poseidon'])} and {type(initial_params['mmr_peaks']['keccak'])} instead"
    assert len(initial_params["mmr_peaks"]["poseidon"]) == len(
        initial_params["mmr_peaks"]["keccak"]
    ), f"mmr_peaks['poseidon'] and mmr_peaks['keccak'] should have the same length. Got {len(initial_params['mmr_peaks']['poseidon'])} and {len(initial_params['mmr_peaks']['keccak'])} instead"
    assert is_valid_mmr_size(
        initial_params["mmr_size"]
    ), f"Invalid MMR size: {initial_params['mmr_size']}"
