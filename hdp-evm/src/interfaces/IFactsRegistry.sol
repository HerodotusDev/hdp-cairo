// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Interface for the facts registry (https://github.com/starkware-libs/starkex-contracts/blob/master/scalable-dex/contracts/src/components/FactRegistry.sol)
interface IFactsRegistry {
    function isValid(bytes32 fact) external view returns (bool);
    function markValid(bytes32 fact) external;
}
