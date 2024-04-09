// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// Not a expected type.
error InvalidType();

/**
 * @dev These functions are used to split and merge uint256 values into two uint128 values.
 */
library Uint256Splitter {
    uint256 public constant MASK = type(uint128).max;

    /// @notice Splits a uint256 into two uint128s (low, high) represented as uint256s.
    /// @param a The uint256 to split.
    function split128(uint256 a) internal pure returns (uint256 lower, uint256 upper) {
        return (a & MASK, a >> 128);
    }

    /// @notice Merges two uint128s (low, high) into one uint256.
    /// @param lower The lower uint256. The caller is required to pass a value that is less than 2^128 - 1.
    /// @param upper The upper uint256.
    function merge128(uint256 lower, uint256 upper) internal pure returns (uint256 a) {
        if (lower > MASK) {
            revert InvalidType();
        }

        /// @solidity memory-safe-assembly
        assembly {
            a := or(shl(128, upper), lower)
        }
    }
}
