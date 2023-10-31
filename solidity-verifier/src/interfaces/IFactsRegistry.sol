// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFactsRegistry {
    function isValid(bytes32 fact) external view returns (bool);
}
