// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {HdpExecutionStore} from "../../src/hdp/HdpExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../../src/hdp/datatypes/BlockSampledDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../../src/hdp/datatypes/ComputationalTaskCodecs.sol";

import {IFactsRegistry} from "../../src/interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../../src/interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../../src/interfaces/IAggregatorsFactory.sol";
import {Uint256Splitter} from "../../src/lib/Uint256Splitter.sol";
import {HexStringConverter} from "../../src/lib/HexStringConverter.sol";

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

contract MockSharpFactsAggregator is ISharpFactsAggregator {
    function aggregatorState() external pure returns (AggregatorState memory) {
        bytes32 root = 0x067e9e103829fd281d8f72d911d8f7c4b146854f79a42a292be46f52a1404ca0;
        return
            AggregatorState({
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

    address proverAddress = address(12);

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

        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));

        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function test_ExecutionOfTaskWithBlockSampledDatalake() public {
        // Note: Step 1. HDP Server receives a request
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399900,
            blockRangeEnd: 10400000,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForHeaderProp(15)
        });

        ComputationalTask memory computationalTask1 = ComputationalTask({
            aggregateFnId: uint256(bytes32("avg")),
            aggregateFnCtx: ""
        });
        ComputationalTask memory computationalTask2 = ComputationalTask({
            aggregateFnId: uint256(bytes32("sum")),
            aggregateFnCtx: ""
        });
        ComputationalTask memory computationalTask3 = ComputationalTask({
            aggregateFnId: uint256(bytes32("min")),
            aggregateFnCtx: ""
        });
        ComputationalTask memory computationalTask4 = ComputationalTask({
            aggregateFnId: uint256(bytes32("max")),
            aggregateFnCtx: ""
        });

        // =================================

        // Note: Step 2. HDP Server call [`requestExecutionOfTaskWithBlockSampledDatalake`] before processing
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask1
        );
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask2
        );
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask3
        );
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask4
        );

        // =================================

        // Note: This step is mocking requestExecutionOfTaskWithBlockSampledDatalake
        // create identifier to check request done correctly
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 task1Commitment = computationalTask1.commit(datalakeCommitment);
        bytes32 task2Commitment = computationalTask2.commit(datalakeCommitment);
        bytes32 task3Commitment = computationalTask3.commit(datalakeCommitment);
        bytes32 task4Commitment = computationalTask4.commit(datalakeCommitment);

        assertEq(
            datalakeCommitment,
            bytes32(
                0x1b7096196e2e7022ef6030726ba512384512b9fd483c7a1e53f88a2411dbdff9
            )
        );
        assertEq(
            task1Commitment,
            bytes32(
                0x1e2311a8fce262c0dd562a3a8f2941dde20456e4648513c027e57d9a2e42a0fd
            )
        );
        assertEq(
            task2Commitment,
            bytes32(
                0xdc5a74b4a205ded78770a65ac344e719d8dfccf9785cb04f6a0660d94f1db15e
            )
        );
        assertEq(
            task3Commitment,
            bytes32(
                0x61af66bad6d54996439357d980be477385a6535493d4590bc3a86625cc750e5a
            )
        );
        assertEq(
            task4Commitment,
            bytes32(
                0x5e5d94142d4abb2d117ee80ad1fdb8f147a0cb3f48d1b4cd02135a1eb21b1c35
            )
        );

        // Check the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp.getTaskStatus(
            task1Commitment
        );
        assertEq(
            uint(task1Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );
        HdpExecutionStore.TaskStatus task2Status = hdp.getTaskStatus(
            task2Commitment
        );
        assertEq(
            uint(task2Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );
        HdpExecutionStore.TaskStatus task3Status = hdp.getTaskStatus(
            task3Commitment
        );
        assertEq(
            uint(task3Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );
        HdpExecutionStore.TaskStatus task4Status = hdp.getTaskStatus(
            task4Commitment
        );
        assertEq(
            uint(task4Status),
            uint(HdpExecutionStore.TaskStatus.SCHEDULED)
        );

        // =================================

        // Note: Step 3. HDP Server process the request sending the tasks to the Rust HDP
        // This step is mocking cli call to Rust HDP

        // Request to cli

        // =================================

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](4);
        encodedDatalakes[0] = datalake.encode();
        encodedDatalakes[1] = datalake.encode();
        encodedDatalakes[2] = datalake.encode();
        encodedDatalakes[3] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](4);
        computationalTasksSerialized[0] = computationalTask1.encode();
        computationalTasksSerialized[1] = computationalTask2.encode();
        computationalTasksSerialized[2] = computationalTask3.encode();
        computationalTasksSerialized[3] = computationalTask4.encode();

        // =================================

        // Response from cli

        // Evaluation Result Key from cli
        bytes32[] memory taskCommitments = new bytes32[](4);
        taskCommitments[0] = task1Commitment;
        taskCommitments[1] = task2Commitment;
        taskCommitments[2] = task3Commitment;
        taskCommitments[3] = task4Commitment;

        // Evaluation Result value from cli
        bytes32[] memory computationalTasksResult = new bytes32[](4);
        computationalTasksResult[0] = bytes32(uint256(11683168316831682560));
        computationalTasksResult[1] = bytes32(uint256(1180000000000000000000));
        computationalTasksResult[2] = bytes32(uint256(10000000000000000000));
        computationalTasksResult[3] = bytes32(uint256(17000000000000000000));

        // Tasks and Results Merkle Tree Information

        bytes32 tasksRoot = 0x772a7bb6877855fdde90d6d8bddde781e23d08cea8cd32822c839e1061732626;
        bytes32 resultsRoot = 0xc1371339523fe5d5e3082a4eda5cbf1d5d2ec2960af43b64e0cfb140c9be9448;

        // proof of the tasks merkle tree
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](
            4
        );
        bytes32[] memory InclusionMerkleProofOfTask1 = new bytes32[](2);
        InclusionMerkleProofOfTask1[
            0
        ] = 0xdaeb56b4fed841576996ff1710a1fa0f1b2f8a4ff73c3b0b1453db93bd7868e5;
        InclusionMerkleProofOfTask1[
            1
        ] = 0x395cbedd6ffad46de3d5dfa879d46c3b9767fbdeb61b80fbe0f352b8da9436aa;
        batchInclusionMerkleProofOfTasks[0] = InclusionMerkleProofOfTask1;
        bytes32[] memory InclusionMerkleProofOfTask2 = new bytes32[](2);
        InclusionMerkleProofOfTask2[
            0
        ] = 0xefe80ee09ad6352ebb1bc03ce4be55ba8ba5660d992478647a1e9a5d85739c14;
        InclusionMerkleProofOfTask2[
            1
        ] = 0x395cbedd6ffad46de3d5dfa879d46c3b9767fbdeb61b80fbe0f352b8da9436aa;
        batchInclusionMerkleProofOfTasks[1] = InclusionMerkleProofOfTask2;
        bytes32[] memory InclusionMerkleProofOfTask3 = new bytes32[](2);
        InclusionMerkleProofOfTask3[
            0
        ] = 0x83e5c05e645f433031b3c2123d7ec5ac00262571c5ed8e8af486c9e9784b46e2;
        InclusionMerkleProofOfTask3[
            1
        ] = 0x0e4c976d1270b096d54f626eb869c5492e858e95c0a0c791ad98465870829794;
        batchInclusionMerkleProofOfTasks[2] = InclusionMerkleProofOfTask3;
        bytes32[] memory InclusionMerkleProofOfTask4 = new bytes32[](2);
        InclusionMerkleProofOfTask4[
            0
        ] = 0x6019bcfc2e4ee019364f70c25f2632f52babb5875780e62ed5f5fdf09fbc361c;
        InclusionMerkleProofOfTask4[
            1
        ] = 0x0e4c976d1270b096d54f626eb869c5492e858e95c0a0c791ad98465870829794;
        batchInclusionMerkleProofOfTasks[3] = InclusionMerkleProofOfTask4;

        // proof of the result
        bytes32[][] memory batchInclusionMerkleProofOfResults = new bytes32[][](
            4
        );
        bytes32[] memory InclusionMerkleProofOfResult1 = new bytes32[](2);
        InclusionMerkleProofOfResult1[
            0
        ] = 0xfe1ff2228e787f8aebe51c3c66d268b750d002c5ad01eec8e95263decce2db51;
        InclusionMerkleProofOfResult1[
            1
        ] = 0x61cc85832a6c21a82e382f2ee3e6463ad010cadf33d48d7ac218f86f6dcbd391;
        batchInclusionMerkleProofOfResults[0] = InclusionMerkleProofOfResult1;
        bytes32[] memory InclusionMerkleProofOfResult2 = new bytes32[](2);
        InclusionMerkleProofOfResult2[
            0
        ] = 0x64e5fda40eb8f1bd3e6fcaf42b6c51be9df9e316b8161d279b837962bedd2050;
        InclusionMerkleProofOfResult2[
            1
        ] = 0x61cc85832a6c21a82e382f2ee3e6463ad010cadf33d48d7ac218f86f6dcbd391;
        batchInclusionMerkleProofOfResults[1] = InclusionMerkleProofOfResult2;
        bytes32[] memory InclusionMerkleProofOfResult3 = new bytes32[](2);
        InclusionMerkleProofOfResult3[
            0
        ] = 0x30979630f4683a16bbaa655005717e678488bf03648fb99df9719f45506878d2;
        InclusionMerkleProofOfResult3[
            1
        ] = 0x15242a688e06db6ab78e51ecfb61e3a82c39f7e2ebd32c49bb71294dbf0f7a32;
        batchInclusionMerkleProofOfResults[2] = InclusionMerkleProofOfResult3;
        bytes32[] memory InclusionMerkleProofOfResult4 = new bytes32[](2);
        InclusionMerkleProofOfResult4[
            0
        ] = 0xa453776e9580b25b9117a8eb1ed970f4b3e01998e947561f253108749d1cf4a8;
        InclusionMerkleProofOfResult4[
            1
        ] = 0x15242a688e06db6ab78e51ecfb61e3a82c39f7e2ebd32c49bb71294dbf0f7a32;
        batchInclusionMerkleProofOfResults[3] = InclusionMerkleProofOfResult4;

        // Convert to Cairo input format
        uint256 tasksRootUint = uint256(tasksRoot);
        (uint256 tasksRootLow, uint256 tasksRootHigh) = Uint256Splitter
            .split128(tasksRootUint);
        uint256 resultsRootUint = uint256(resultsRoot);
        (uint256 resultsRootLow, uint256 resultsRootHigh) = Uint256Splitter
            .split128(resultsRootUint);
        // root of tasks merkle tree
        uint128 scheduledTasksBatchMerkleRootLow = uint128(tasksRootLow);
        uint128 scheduledTasksBatchMerkleRootHigh = uint128(tasksRootHigh);
        // root of result merkle tree
        uint128 batchResultsMerkleRootLow = uint128(resultsRootLow);
        uint128 batchResultsMerkleRootHigh = uint128(resultsRootHigh);

        // MMR metadata
        uint256 usedMmrId = 24;
        uint256 usedMmrSize = 209371;

        // =================================

        // Cache MMR root
        hdp.cacheMmrRoot(usedMmrId);

        // Mocking Cairo Program, insert the fact into the registry
        bytes32 factHash = getFactHash(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh
        );
        factsRegistry.markValid(factHash);
        bool is_valid = factsRegistry.isValid(factHash);
        assertEq(is_valid, true);

        // =================================

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        vm.prank(proverAddress);
        hdp.authenticateTaskExecution(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh,
            batchInclusionMerkleProofOfTasks,
            batchInclusionMerkleProofOfResults,
            computationalTasksResult,
            taskCommitments
        );

        // Check if the task state is FINALIZED
        HdpExecutionStore.TaskStatus task1StatusAfter = hdp.getTaskStatus(
            task1Commitment
        );
        assertEq(
            uint(task1StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );
        HdpExecutionStore.TaskStatus task2StatusAfter = hdp.getTaskStatus(
            task2Commitment
        );
        assertEq(
            uint(task2StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );
        HdpExecutionStore.TaskStatus task3StatusAfter = hdp.getTaskStatus(
            task3Commitment
        );
        assertEq(
            uint(task3StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );
        HdpExecutionStore.TaskStatus task4StatusAfter = hdp.getTaskStatus(
            task4Commitment
        );
        assertEq(
            uint(task4StatusAfter),
            uint(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes32 task1Result = hdp.getFinalizedTaskResult(task1Commitment);
        assertEq(task1Result, computationalTasksResult[0]);
        bytes32 task2Result = hdp.getFinalizedTaskResult(task2Commitment);
        assertEq(task2Result, computationalTasksResult[1]);
        bytes32 task3Result = hdp.getFinalizedTaskResult(task3Commitment);
        assertEq(task3Result, computationalTasksResult[2]);
        bytes32 task4Result = hdp.getFinalizedTaskResult(task4Commitment);
        assertEq(task4Result, computationalTasksResult[3]);
    }

    function testFactHashWithServer() public {
        uint256 usedMmrId = 1;
        uint256 usedMmrSize = 2397;
        uint256 taskMerkleRoot = uint256(
            bytes32(
                0x730f1037780b3b53cfaecdb95fc648ce719479a58afd4325a62b0c5e09e83090
            )
        );
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(
            taskMerkleRoot
        );
        uint128 scheduledTasksBatchMerkleRootLow = 0x719479a58afd4325a62b0c5e09e83090;
        uint128 scheduledTasksBatchMerkleRootHigh = 0x730f1037780b3b53cfaecdb95fc648ce;
        assertEq(scheduledTasksBatchMerkleRootLow, taskRootLow);
        assertEq(scheduledTasksBatchMerkleRootHigh, taskRootHigh);

        uint256 resultMerkleRoot = uint256(
            bytes32(
                0xb65f3b91a4ee075433cc735ce53857b0fe215e96c83498ff6eaba24e09892e4b
            )
        );
        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter
            .split128(resultMerkleRoot);
        uint128 batchResultsMerkleRootLow = 0xfe215e96c83498ff6eaba24e09892e4b;
        uint128 batchResultsMerkleRootHigh = 0xb65f3b91a4ee075433cc735ce53857b0;
        assertEq(batchResultsMerkleRootLow, resultRootLow);
        assertEq(batchResultsMerkleRootHigh, resultRootHigh);

        bytes32 factHash = getFactHash(
            usedMmrId,
            usedMmrSize,
            batchResultsMerkleRootLow,
            batchResultsMerkleRootHigh,
            scheduledTasksBatchMerkleRootLow,
            scheduledTasksBatchMerkleRootHigh
        );

        assertEq(
            factHash,
            bytes32(
                0x0cbe06fd748ba4f3517eebe5e8549528f970c1dc7ec8344908b6682c6230c9e9
            )
        );
    }

    function getFactHash(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh
    ) internal view returns (bytes32) {
        // Load MMRs root
        bytes32 usedMmrRoot = hdp.loadMmrRoot(usedMmrId, usedMmrSize);
        // Initialize an array of uint256 to store the program output
        uint256[] memory programOutput = new uint256[](6);

        // Assign values to the program output array
        programOutput[0] = uint256(usedMmrRoot);
        programOutput[1] = uint256(usedMmrSize);
        programOutput[2] = uint256(batchResultsMerkleRootLow);
        programOutput[3] = uint256(batchResultsMerkleRootHigh);
        programOutput[4] = uint256(scheduledTasksBatchMerkleRootLow);
        programOutput[5] = uint256(scheduledTasksBatchMerkleRootHigh);

        // Compute program output hash
        bytes32 programOutputHash = keccak256(abi.encode(programOutput));

        // Compute GPS fact hash
        bytes32 gpsFactHash = keccak256(
            abi.encode(
                bytes32(
                    uint256(
                        0x66154754a3e3a07b6bb7f1a6c2259703621f4d1f616b5f4ae74d9863d74fba9
                    )
                ),
                programOutputHash
            )
        );

        return gpsFactHash;
    }
}
