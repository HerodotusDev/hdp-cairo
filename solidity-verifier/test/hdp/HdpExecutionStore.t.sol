// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {HdpExecutionStore} from "../../src/hdp/HdpExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../../src/hdp/datatypes/BlockSampledDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../../src/hdp/datatypes/ComputationalTaskCodecs.sol";

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
        // poseidon need to be padded to store in bytes32
        bytes32 root = 0x067e9e103829fd281d8f72d911d8f7c4b146854f79a42a292be46f52a1404ca0;
        return AggregatorState({
            poseidonMmrRoot: root,
            keccakMmrRoot: bytes32(0),
            mmrSize: 209371,
            continuableParentHash: bytes32(0)
        });
    }
}

contract HreExecutionStoreTest is Test {
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    HdpExecutionStore private hdp;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;
    ISharpFactsAggregator private sharpFactsAggregator;

    function setUp() public {
        // Registery for facts that has been processed through SHARP
        factsRegistry = new MockFactsRegistry();
        // Factory for creating SHARP facts aggregators
        aggregatorsFactory = new MockAggregatorsFactory();
        // Mock SHARP facts aggregator
        sharpFactsAggregator = new MockSharpFactsAggregator();
        hdp = new HdpExecutionStore(factsRegistry, aggregatorsFactory);

        // Step 0. Create mock SHARP facts aggregator mmr id 24
        aggregatorsFactory.createAggregator(24, sharpFactsAggregator);

        // For testing, set msg.sender as prover
        hdp.grantRole(keccak256("PROVER_ROLE"), address(this));
    }

    function test_requestExecutionOfTaskWithBlockSampledDatalake() public {
        // Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399990,
            blockRangeEnd: 10400000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs.encodeSampledPropertyForHeaderProp(15)
        });
        ComputationalTask memory computationalTask =
            ComputationalTask({aggregateFnId: uint256(bytes32("avg")), aggregateFnCtx: ""});
        // =================================

        // Emit the event in there when call request
        // TODO: usedMMRsPacked format should be defined
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(datalake, computationalTask, 24);

        // =================================
        // Step 3. Rust HDP and Cairo HDP is triggered due to the event
        // SHARP Facts Registry should be registered with the new fact
        // and updated to new facts emit event which listen by HDP server
        // =================================
    }

    function test_authenticateTaskExecution() public {
        // Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399990,
            blockRangeEnd: 10400000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs.encodeSampledPropertyForHeaderProp(15)
        });
        ComputationalTask memory computationalTask =
            ComputationalTask({aggregateFnId: uint256(bytes32("avg")), aggregateFnCtx: ""});
        // =================================

        // Responses from HDP
        // encode with mmr id and mmr size
        // TODO: usedMMRsPacked format should be defined
        uint256 usedMMRsPacked = 24;
        // root of tasks merkle tree
        bytes32 scheduledTasksBatchMerkleRoot = bytes32(0);
        // root of result merkle tree
        bytes32 batchResultsMerkleRoot = bytes32(0);
        // proof of the task
        bytes32[] memory batchInclusionMerkleProofOfTask = new bytes32[](2);
        // proof of the result
        bytes32[] memory batchInclusionMerkleProofOfResult = new bytes32[](2);
        // encoded task
        bytes memory computationalTaskSerialized = computationalTask.encode();
        // encoded result
        bytes memory computationalTaskResult = datalake.encode();

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        // TODO: Caller should be prover
        hdp.authenticateTaskExecution(
            usedMMRsPacked,
            scheduledTasksBatchMerkleRoot,
            batchResultsMerkleRoot,
            batchInclusionMerkleProofOfTask,
            batchInclusionMerkleProofOfResult,
            computationalTaskSerialized,
            computationalTaskResult
        );
    }
}