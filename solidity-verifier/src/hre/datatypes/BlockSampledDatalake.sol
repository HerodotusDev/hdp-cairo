// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DatalakeCode} from "./DatalakeCodes.sol";

struct BlockSampledDatalake {
    uint256 blockRangeStart;
    uint256 blockRangeEnd;
    uint256 increment;
    bytes sampledProperty;
}

library BlockSampledDatalakeCodecs {
    function encode(
        BlockSampledDatalake memory datalake
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                DatalakeCode.BlockSampled,
                datalake.blockRangeStart,
                datalake.blockRangeEnd,
                datalake.increment,
                datalake.sampledProperty
            );
    }

    function commit(
        BlockSampledDatalake memory datalake
    ) internal pure returns (bytes32) {
        return keccak256(encode(datalake));
    }

    function encodeSampledPropertyForHeaderProp(
        uint8 headerPropId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(1), headerPropId);
    }

    function encodeSampledPropertyForAccount(
        address account,
        uint8 propertyId
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(2), account, propertyId);
    }

    function encodeSampledPropertyForStorage(
        address account,
        bytes32 slot
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint8(3), account, slot);
    }

    function decode(
        bytes memory data
    ) internal pure returns (BlockSampledDatalake memory) {
        (
            ,
            uint256 blockRangeStart,
            uint256 blockRangeEnd,
            uint256 increment,
            bytes memory sampledProperty
        ) = abi.decode(data, (DatalakeCode, uint256, uint256, uint256, bytes));
        return
            BlockSampledDatalake({
                blockRangeStart: blockRangeStart,
                blockRangeEnd: blockRangeEnd,
                increment: increment,
                sampledProperty: sampledProperty
            });
    }
}
