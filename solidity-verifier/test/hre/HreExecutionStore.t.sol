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

    function createAggregator(uint256 id, ISharpFactsAggregator aggregator) external {
        aggregatorsById[id] = aggregator;
    }
}

contract MockSharpFactsAggregator is ISharpFactsAggregator {
    function aggregatorState() external view returns (AggregatorState memory) {
        return AggregatorState({
            poseidonMmrRoot: bytes32(0),
            keccakMmrRoot: bytes32(0),
            mmrSize: 0,
            continuableParentHash: bytes32(0)
        });
    }
}

contract HreExecutionStoreTest is Test {
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    HreExecutionStore private hre;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;
    ISharpFactsAggregator private sharpFactsAggregator;

    function setUp() public {
        factsRegistry = new MockFactsRegistry();
        aggregatorsFactory = new MockAggregatorsFactory();
        sharpFactsAggregator = new MockSharpFactsAggregator();
        hre = new HreExecutionStore(factsRegistry, aggregatorsFactory);

        // Step 0. Prefill the mock facts registry
        aggregatorsFactory.createAggregator(24, sharpFactsAggregator);

        // Step 1. When HDP API received request (TS),
        // it should cache the MMR ids relavant to the request (= batched tasks)
        uint256 mmrId = 24;
        hre.cacheMmrRoot(mmrId);
    }

    function test_requestExecutionOfTaskWithBlockSampledDatalake() public {
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399990,
            blockRangeEnd: 10400000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs.encodeSampledPropertyForHeaderProp(15)
        });
        ComputationalTask memory computationalTask =
            ComputationalTask({aggregateFnId: uint256(bytes32("avg")), aggregateFnCtx: ""});

        hre.requestExecutionOfTaskWithBlockSampledDatalake(datalake, computationalTask);

        //     // FFI
        //     bytes[] memory encodedDatalakes = new bytes[](4);
        //     encodedDatalakes[0] = datalake.encode();
        //     encodedDatalakes[1] = datalake.encode();
        //     encodedDatalakes[2] = datalake.encode();
        //     encodedDatalakes[3] = datalake.encode();

        //     bytes[] memory encodedComputationalTasks = new bytes[](4);
        //     encodedComputationalTasks[0] = ComputationalTask({
        //         aggregateFnId: uint256(bytes32("avg")),
        //         aggregateFnCtx: ""
        //     }).encode();
        //     encodedComputationalTasks[1] = ComputationalTask({
        //         aggregateFnId: uint256(bytes32("sum")),
        //         aggregateFnCtx: ""
        //     }).encode();
        //     encodedComputationalTasks[2] = ComputationalTask({
        //         aggregateFnId: uint256(bytes32("min")),
        //         aggregateFnCtx: ""
        //     }).encode();
        //     encodedComputationalTasks[3] = ComputationalTask({
        //         aggregateFnId: uint256(bytes32("max")),
        //         aggregateFnCtx: ""
        //     }).encode();

        //     (bytes32 tasksRoot, bytes32 resultsRoot) = processBatchThroughFFI(
        //         encodedDatalakes,
        //         encodedComputationalTasks
        //     );
    }

    // function processBatchThroughFFI(
    //     bytes[] memory encodedDatalakes,
    //     bytes[] memory encodedComputationalTasks
    // ) internal returns (bytes32 tasksRoot, bytes32 resultsRoot) {
    //     // Ensure length match
    //     require(
    //         encodedDatalakes.length == encodedComputationalTasks.length,
    //         "Length mismatch"
    //     );

    //     string[] memory inputsExtended = new string[](3);
    //     inputsExtended[0] = "python3 ./helpers/printer.py";
    //     inputsExtended[1] = string(abi.encode(encodedDatalakes));
    //     inputsExtended[2] = string(abi.encode(encodedComputationalTasks));

    //     console.logBytes(abi.encode(encodedDatalakes));
    //     console.logBytes(abi.encode(encodedComputationalTasks));
    //     bytes memory outputExtended = vm.ffi(inputsExtended);
    // }
}
