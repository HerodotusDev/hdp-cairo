// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {HreExecutionStore} from "../../src/hre/HreExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../../src/hre/datatypes/BlockSampledDatalake.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../../src/hre/datatypes/ComputationalTask.sol";

import {IFactsRegistry} from "../../src/interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../../src/interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../../src/interfaces/IAggregatorsFactory.sol";

contract MockFactsRegistry is IFactsRegistry {
    mapping(bytes32 => bool) public isValid;

    function markValid(bytes32 fact) public {
        isValid[fact] = true;
    }
}

contract MockAggregatorsFactory is IAggregatorsFactory {
    mapping(uint256 => ISharpFactsAggregator) public aggregatorsById;

    function createAggregator(
        uint256 id,
        ISharpFactsAggregator aggregator
    ) external {
        aggregatorsById[id] = aggregator;
    }
}

contract HreExecutionStoreTest is Test {
    HreExecutionStore private hre;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;

    function setUp() public {
        factsRegistry = new MockFactsRegistry();
        aggregatorsFactory = new MockAggregatorsFactory();
        hre = new HreExecutionStore(factsRegistry, aggregatorsFactory);
    }

    function test_requestExecutionOfTaskWithBlockSampledDatalake() public {
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 1000,
            blockRangeEnd: 2000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForHeaderProp(15)
        });
        ComputationalTask memory computationalTask = ComputationalTask({
            aggregateFnId: uint256(bytes32("avg")),
            aggregateFnCtx: ""
        });

        hre.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask
        );
    }
}
