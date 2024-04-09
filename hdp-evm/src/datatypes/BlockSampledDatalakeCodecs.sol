// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {DatalakeCode} from "./Datalake.sol";

/// @dev A BlockSampledDatalake.
/// @param blockRangeStart The start block of the range.
/// @param blockRangeEnd The end block of the range.
/// @param increment The block increment.
/// @param sampledProperty The detail property to sample.
struct BlockSampledDatalake {
    uint256 blockRangeStart;
    uint256 blockRangeEnd;
    uint256 increment;
    bytes sampledProperty;
}

/// @notice Codecs for BlockSampledDatalake.
/// @dev Represent a datalake that samples a property at a fixed block interval.
library BlockSampledDatalakeCodecs {
    /// @dev Encodes a BlockSampledDatalake.
    /// @param datalake The BlockSampledDatalake to encode.
    function encode(BlockSampledDatalake memory datalake) internal pure returns (bytes memory) {
        return abi.encode(
            DatalakeCode.BlockSampled,
            datalake.blockRangeStart,
            datalake.blockRangeEnd,
            datalake.increment,
            datalake.sampledProperty
        );
    }

    /// @dev Get the commitment of a BlockSampledDatalake.
    /// @param datalake The BlockSampledDatalake to commit.
    function commit(BlockSampledDatalake memory datalake) internal pure returns (bytes32) {
        return keccak256(encode(datalake));
    }

    /// @dev Encodes a sampled property for a header property.
    /// @param headerPropId The header field from rlp decoded block header.
    function encodeSampledPropertyForHeaderProp(uint8 headerPropId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), headerPropId);
    }

    /// @dev Encodes a sampled property for an account property.
    /// @param account The account address.
    /// @param propertyId The account field from rlp decoded account.
    function encodeSampledPropertyForAccount(address account, uint8 propertyId) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(2), account, propertyId);
    }

    /// @dev Encodes a sampled property for a storage.
    /// @param account The account address.
    /// @param slot The storage key.
    function encodeSampledPropertyForStorage(address account, bytes32 slot) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(3), account, slot);
    }

    /// @dev Decodes a BlockSampledDatalake.
    /// @param data The encoded BlockSampledDatalake.
    function decode(bytes memory data) internal pure returns (BlockSampledDatalake memory) {
        (, uint256 blockRangeStart, uint256 blockRangeEnd, uint256 increment, bytes memory sampledProperty) =
            abi.decode(data, (DatalakeCode, uint256, uint256, uint256, bytes));
        return BlockSampledDatalake({
            blockRangeStart: blockRangeStart,
            blockRangeEnd: blockRangeEnd,
            increment: increment,
            sampledProperty: sampledProperty
        });
    }
}
