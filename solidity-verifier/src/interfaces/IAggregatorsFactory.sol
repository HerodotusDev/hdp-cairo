// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISharpFactsAggregator} from "./ISharpFactsAggregator.sol";

interface IAggregatorsFactory {
    function createAggregator(uint256 id, ISharpFactsAggregator aggregator) external;

    function aggregatorsById(uint256 id) external view returns (ISharpFactsAggregator);
}
