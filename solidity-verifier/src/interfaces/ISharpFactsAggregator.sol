// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISharpFactsAggregator {
    struct AggregatorState {
        bytes32 poseidonMmrRoot;
        bytes32 keccakMmrRoot;
        uint256 mmrSize;
        bytes32 continuableParentHash;
    }

    function aggregatorState() external view returns (AggregatorState memory);
}
