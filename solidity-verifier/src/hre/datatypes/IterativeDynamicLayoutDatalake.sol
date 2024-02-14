// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DatalakeCode} from "./DatalakeCodes.sol";

struct IterativeDynamicLayoutDatalake {
    uint256 blockNumber;
    address account;
    uint256 slotIndex;
    uint256 initialKey;
    uint256 keyBoundry;
    uint256 increment;
}

library IterativeDynamicLayoutDatalakeCodecs {
    function encode(IterativeDynamicLayoutDatalake memory datalake) internal pure returns (bytes memory) {
        return abi.encode(
            DatalakeCode.IterativeDynamicLayout,
            datalake.blockNumber,
            datalake.account,
            datalake.slotIndex,
            datalake.initialKey,
            datalake.keyBoundry,
            datalake.increment
        );
    }

    function commit(IterativeDynamicLayoutDatalake memory datalake) internal pure returns (bytes32) {
        return keccak256(encode(datalake));
    }

    function decode(bytes memory data) internal pure returns (IterativeDynamicLayoutDatalake memory) {
        (
            ,
            uint256 blockNumber,
            address account,
            uint256 slotIndex,
            uint256 initialKey,
            uint256 keyBoundry,
            uint256 increment
        ) = abi.decode(data, (DatalakeCode, uint256, address, uint256, uint256, uint256, uint256));
        return IterativeDynamicLayoutDatalake({
            blockNumber: blockNumber,
            account: account,
            slotIndex: slotIndex,
            initialKey: initialKey,
            keyBoundry: keyBoundry,
            increment: increment
        });
    }
}
