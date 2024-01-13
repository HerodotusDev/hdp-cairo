// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISharpFactsAggregator} from "./ISharpFactsAggregator.sol";

interface IAggregatorsFactory {
    function aggregatorsById(
        uint256 id
    ) external view returns (ISharpFactsAggregator);
}
