// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {HdpExecutionStore} from "../src/HdpExecutionStore.sol";
import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "../src/datatypes/BlockSampledDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "../src/datatypes/ComputationalTaskCodecs.sol";
import {AggregateFn, Operator} from "../src/datatypes/ComputationalTaskCodecs.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../src/interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../src/interfaces/IAggregatorsFactory.sol";
import {Uint256Splitter} from "../src/lib/Uint256Splitter.sol";

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
        bytes32 root = 0x010985193855d9de012ae065d02e15676aa2cce031b18290d3b48fb8e410d3bc;
        return
            AggregatorState({
                poseidonMmrRoot: root,
                keccakMmrRoot: bytes32(0),
                mmrSize: 56994,
                continuableParentHash: bytes32(0)
            });
    }
}

contract MockSharpFactsAggregator2 is ISharpFactsAggregator {
    function aggregatorState() external pure returns (AggregatorState memory) {
        bytes32 root = 0x03487af623d7acba1505bfac5690d1a80c96590f5f5f40e6485861eb4e69c63e;
        return
            AggregatorState({
                poseidonMmrRoot: root,
                keccakMmrRoot: bytes32(0),
                mmrSize: 1215237,
                continuableParentHash: bytes32(0)
            });
    }
}

contract HdpExecutionStoreTest is Test {
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    address public proverAddress = address(12);

    HdpExecutionStore private hdp;
    HdpExecutionStore private hdp2;

    IFactsRegistry private factsRegistry;
    IAggregatorsFactory private aggregatorsFactory;

    ISharpFactsAggregator private sharpFactsAggregator;
    ISharpFactsAggregator private sharpFactsAggregator2;

    function setUp() public {
        // Registery for facts that has been processed through SHARP
        factsRegistry = new MockFactsRegistry();
        // Factory for creating SHARP facts aggregators
        aggregatorsFactory = new MockAggregatorsFactory();
        // Mock SHARP facts aggregator
        sharpFactsAggregator = new MockSharpFactsAggregator();
        sharpFactsAggregator2 = new MockSharpFactsAggregator2();
        hdp = new HdpExecutionStore(factsRegistry, aggregatorsFactory);
        hdp2 = new HdpExecutionStore(factsRegistry, aggregatorsFactory);

        // Step 0. Create mock SHARP facts aggregator mmr id 2
        aggregatorsFactory.createAggregator(2, sharpFactsAggregator);

        // Step 0. Create mock SHARP facts aggregator mmr id 19
        aggregatorsFactory.createAggregator(19, sharpFactsAggregator2);

        assertTrue(hdp.hasRole(keccak256("OPERATOR_ROLE"), address(this)));

        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);

        assertTrue(hdp2.hasRole(keccak256("OPERATOR_ROLE"), address(this)));

        hdp2.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function testSingleBlockSingleBlockSampledDatalake() public {
        // hdp encode -a -b 4952100 4952100 "account.0x7f2C6f930306D3AA736B3A6C6A98f512F74036D4.nonce" 1
        // Note: Step 1. HDP Server receives a request
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 4952100,
            blockRangeEnd: 4952100,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForAccount(
                    address(0x7f2C6f930306D3AA736B3A6C6A98f512F74036D4),
                    uint8(0)
                )
        });

        ComputationalTask memory computationalTask = ComputationalTask({
            aggregateFnId: AggregateFn.SUM,
            operatorId: Operator.NONE,
            valueToCompare: uint256(0)
        });

        // =================================

        // Note: Step 2. HDP Server call [`requestExecutionOfTaskWithBlockSampledDatalake`] before processing
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask
        );

        // =================================

        // Note: This step is mocking requestExecutionOfTaskWithBlockSampledDatalake
        // create identifier to check request done correctly
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        assertEq(
            taskCommitment,
            bytes32(
                0xa8a1306d7f51289d0731a64579765e34a672ddc247c2c10752596dd53150b00e
            )
        );

        // Check the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp.getTaskStatus(
            taskCommitment
        );
        assertEq(
            uint256(task1Status),
            uint256(HdpExecutionStore.TaskStatus.SCHEDULED)
        );

        // =================================

        // Note: Step 3. HDP Server process the request sending the tasks to the Rust HDP
        // This step is mocking cli call to Rust HDP

        // Request to cli

        // =================================

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](1);
        encodedDatalakes[0] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](1);
        computationalTasksSerialized[0] = computationalTask.encode();

        // =================================

        // Response from cli

        // Evaluation Result Key from cli
        bytes32[] memory taskCommitments = new bytes32[](1);
        taskCommitments[0] = taskCommitment;

        // Evaluation Result value from cli
        bytes32[] memory computationalTasksResult = new bytes32[](1);
        computationalTasksResult[0] = bytes32(uint256(6776));

        bytes32 taskResultCommitment1 = keccak256(
            abi.encode(taskCommitment, computationalTasksResult[0])
        );

        assertEq(
            taskResultCommitment1,
            bytes32(
                0x9ce0534899d786d8a51a2bc471d4894d61c8c723d8b31174c838014aa99acf9b
            )
        );

        // Tasks and Results Merkle Tree Information
        // proof of the tasks merkle tree
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](
            1
        );
        bytes32[] memory inclusionMerkleProofOfTask1 = new bytes32[](0);
        batchInclusionMerkleProofOfTasks[0] = inclusionMerkleProofOfTask1;

        // proof of the result
        bytes32[][] memory batchInclusionMerkleProofOfResults = new bytes32[][](
            1
        );
        bytes32[] memory inclusionMerkleProofOfResult1 = new bytes32[](0);
        batchInclusionMerkleProofOfResults[0] = inclusionMerkleProofOfResult1;

        uint256 taskMerkleRoot = uint256(
            bytes32(
                0x3a2f682184c8f04070193cb3c5a0a5c519cfda71c5ae8d39090c6ed0aa9d7aa1
            )
        );
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(
            taskMerkleRoot
        );
        uint128 scheduledTasksBatchMerkleRootLow = 0x19cfda71c5ae8d39090c6ed0aa9d7aa1;
        uint128 scheduledTasksBatchMerkleRootHigh = 0x3a2f682184c8f04070193cb3c5a0a5c5;
        assertEq(scheduledTasksBatchMerkleRootLow, taskRootLow);
        assertEq(scheduledTasksBatchMerkleRootHigh, taskRootHigh);

        uint256 resultMerkleRoot = uint256(
            bytes32(
                0x8ddadb3a246d9988d78871b11dca322a2df53381bfacb9edc42cedfd263b691d
            )
        );
        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter
            .split128(resultMerkleRoot);
        uint128 batchResultsMerkleRootLow = 0x2df53381bfacb9edc42cedfd263b691d;
        uint128 batchResultsMerkleRootHigh = 0x8ddadb3a246d9988d78871b11dca322a;
        assertEq(batchResultsMerkleRootLow, resultRootLow);
        assertEq(batchResultsMerkleRootHigh, resultRootHigh);

        // MMR metadata
        uint256 usedMmrId = 19;
        uint256 usedMmrSize = 1215237;

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
        assertEq(
            factHash,
            bytes32(
                0x57b0d769b9c7cb45ba549e3170ad0c2558ba598e5d2f170d94cefdcbbf3f99ce
            )
        );
        factsRegistry.markValid(factHash);
        bool isValid = factsRegistry.isValid(factHash);
        assertEq(isValid, true);

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
            taskCommitment
        );
        assertEq(
            uint256(task1StatusAfter),
            uint256(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes32 task1Result = hdp.getFinalizedTaskResult(taskCommitment);
        assertEq(task1Result, computationalTasksResult[0]);
    }

    function testBlockHeaderBlockSampledDatalakeCount() public {
        // hdp encode -a count gt.100000 -b 5515000 5515029 "header.blob_gas_used" 1
        // Note: Step 1. HDP Server receives a request
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 5515000,
            blockRangeEnd: 5515029,
            increment: 1,
            sampledProperty: BlockSampledDatalakeCodecs
                .encodeSampledPropertyForHeaderProp(uint8(17))
        });

        ComputationalTask memory computationalTask = ComputationalTask({
            aggregateFnId: AggregateFn.COUNT,
            operatorId: Operator.GT,
            valueToCompare: uint256(100000)
        });

        // =================================

        // Note: Step 2. HDP Server call [`requestExecutionOfTaskWithBlockSampledDatalake`] before processing
        hdp2.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask
        );

        // =================================

        // Note: This step is mocking requestExecutionOfTaskWithBlockSampledDatalake
        // create identifier to check request done correctly
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        assertEq(
            taskCommitment,
            bytes32(
                0x631a92d0413783f63a6b8f8f226f6fd1ce01de4d534375e3b59555d245974954
            )
        );

        // Check the task state is PENDING
        HdpExecutionStore.TaskStatus task1Status = hdp2.getTaskStatus(
            taskCommitment
        );
        assertEq(
            uint256(task1Status),
            uint256(HdpExecutionStore.TaskStatus.SCHEDULED)
        );

        // =================================

        // Note: Step 3. HDP Server process the request sending the tasks to the Rust HDP
        // This step is mocking cli call to Rust HDP

        // Request to cli

        // =================================

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](1);
        encodedDatalakes[0] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](1);
        computationalTasksSerialized[0] = computationalTask.encode();

        // =================================

        // Response from cli

        // Evaluation Result Key from cli
        bytes32[] memory taskCommitments = new bytes32[](1);
        taskCommitments[0] = taskCommitment;

        assertEq(
            taskCommitments[0],
            bytes32(
                0x631a92d0413783f63a6b8f8f226f6fd1ce01de4d534375e3b59555d245974954
            )
        );

        // Evaluation Result value from cli
        bytes32[] memory computationalTasksResult = new bytes32[](1);
        computationalTasksResult[0] = bytes32(uint256(23));

        bytes32 taskResultCommitment1 = keccak256(
            abi.encode(taskCommitment, computationalTasksResult[0])
        );

        assertEq(
            taskCommitment,
            bytes32(
                0x631a92d0413783f63a6b8f8f226f6fd1ce01de4d534375e3b59555d245974954
            )
        );

        assertEq(
            taskResultCommitment1,
            bytes32(
                0x1c7caaf1a635ce660411286890a97ec8912fb1b583b56eb8f71153f3d3acd631
            )
        );

        // Tasks and Results Merkle Tree Information
        // proof of the tasks merkle tree
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](
            1
        );
        bytes32[] memory inclusionMerkleProofOfTask1 = new bytes32[](0);
        batchInclusionMerkleProofOfTasks[0] = inclusionMerkleProofOfTask1;

        // proof of the result
        bytes32[][] memory batchInclusionMerkleProofOfResults = new bytes32[][](
            1
        );
        bytes32[] memory inclusionMerkleProofOfResult1 = new bytes32[](0);
        batchInclusionMerkleProofOfResults[0] = inclusionMerkleProofOfResult1;

        uint256 taskMerkleRoot = uint256(
            bytes32(
                0x42273215b02c4d30f4b986e12013cd44459c6b8d18f7ade57b8180e104e06e80
            )
        );
        (uint256 taskRootLow, uint256 taskRootHigh) = Uint256Splitter.split128(
            taskMerkleRoot
        );
        uint128 scheduledTasksBatchMerkleRootLow = 0x459c6b8d18f7ade57b8180e104e06e80;
        uint128 scheduledTasksBatchMerkleRootHigh = 0x42273215b02c4d30f4b986e12013cd44;
        assertEq(scheduledTasksBatchMerkleRootLow, taskRootLow);
        assertEq(scheduledTasksBatchMerkleRootHigh, taskRootHigh);

        uint256 resultMerkleRoot = uint256(
            bytes32(
                0x63549254b8ea402aa8adbc1f0646ee0965cfcf426bcffb95002fb5e2ea8c6f9b
            )
        );
        (uint256 resultRootLow, uint256 resultRootHigh) = Uint256Splitter
            .split128(resultMerkleRoot);
        uint128 batchResultsMerkleRootLow = 0x65cfcf426bcffb95002fb5e2ea8c6f9b;
        uint128 batchResultsMerkleRootHigh = 0x63549254b8ea402aa8adbc1f0646ee09;
        assertEq(batchResultsMerkleRootLow, resultRootLow);
        assertEq(batchResultsMerkleRootHigh, resultRootHigh);

        // MMR metadata
        uint256 usedMmrId = 19;
        uint256 usedMmrSize = 1215237;

        // =================================

        // Cache MMR root
        hdp2.cacheMmrRoot(usedMmrId);

        bytes32 loadRoot = hdp2.loadMmrRoot(usedMmrId, usedMmrSize);

        assertEq(
            loadRoot,
            bytes32(
                0x03487af623d7acba1505bfac5690d1a80c96590f5f5f40e6485861eb4e69c63e
            )
        );

        // Mocking Cairo Program, insert the fact into the registry
        bytes32 factHash = getFactHash2(
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
                0xaca2ec9a009599561432bf0c88755198d232c0b723346b3e151052710181b1f8
            )
        );
        factsRegistry.markValid(factHash);
        bool isValid = factsRegistry.isValid(factHash);
        assertEq(isValid, true);

        // =================================

        // Check if the request is valid in the SHARP Facts Registry
        // If valid, Store the task result
        vm.prank(proverAddress);

        hdp2.authenticateTaskExecution(
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
        HdpExecutionStore.TaskStatus task1StatusAfter = hdp2.getTaskStatus(
            taskCommitment
        );
        assertEq(
            uint256(task1StatusAfter),
            uint256(HdpExecutionStore.TaskStatus.FINALIZED)
        );

        // Check if the task result is stored
        bytes32 task1Result = hdp2.getFinalizedTaskResult(taskCommitment);
        assertEq(task1Result, computationalTasksResult[0]);
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
        bytes32 programOutputHash = keccak256(abi.encodePacked(programOutput));

        // Compute GPS fact hash
        bytes32 programHash = 0x0099423699f60ef2e51458ec9890eb9ee3ea011067337b8009ab6adcbac6148e;
        bytes32 gpsFactHash = keccak256(
            abi.encode(programHash, programOutputHash)
        );

        return gpsFactHash;
    }

    function getFactHash2(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh
    ) internal view returns (bytes32) {
        // Load MMRs root
        bytes32 usedMmrRoot = hdp2.loadMmrRoot(usedMmrId, usedMmrSize);
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
        bytes32 programOutputHash = keccak256(abi.encodePacked(programOutput));

        // Compute GPS fact hash
        bytes32 programHash = 0x0099423699f60ef2e51458ec9890eb9ee3ea011067337b8009ab6adcbac6148e;
        bytes32 gpsFactHash = keccak256(
            abi.encode(programHash, programOutputHash)
        );

        return gpsFactHash;
    }
}
