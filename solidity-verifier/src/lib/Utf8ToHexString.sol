// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Utf8ToHexString {
    function concatenateAndConvert(
        bytes[] memory data
    ) internal pure returns (string memory) {
        bytes memory concatenatedHex;
        for (uint i = 0; i < data.length; i++) {
            // Convert each bytes element to a hexadecimal string and concatenate
            concatenatedHex = abi.encodePacked(
                concatenatedHex,
                _convert(string(data[i]))
            );
        }
        return string(concatenatedHex);
    }

    function _convert(
        string memory _string
    ) private pure returns (string memory) {
        bytes memory stringBytes = bytes(_string);
        bytes memory resultBytes = new bytes(stringBytes.length * 2);
        uint256 resultIndex = 0;
        for (uint256 i = 0; i < stringBytes.length; i++) {
            uint8 char = uint8(stringBytes[i]);
            resultBytes[resultIndex++] = _toHex(char / 16);
            resultBytes[resultIndex++] = _toHex(char % 16);
        }
        return string(resultBytes);
    }

    function _toHex(uint8 _char) private pure returns (bytes1) {
        return _char < 10 ? bytes1(_char + 0x30) : bytes1(_char + 0x57);
    }
}
