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
        bytes32 admin_role = hdp.getRoleAdmin(keccak256("OPERATOR_ROLE"));
        console.logBytes32(admin_role);
        hdp.grantRole(keccak256("OPERATOR_ROLE"), proverAddress);
    }

    function test_ExecutionOfTaskWithBlockSampledDatalake() public {
        // [1 Request = N Tasks] Request execution of task with block sampled datalake
        BlockSampledDatalake memory datalake = BlockSampledDatalake({
            blockRangeStart: 10399990,
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

        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask1,
            24
        );

        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask2,
            24
        );
        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask3,
            24
        );
        // Emit the event in there when call request
        hdp.requestExecutionOfTaskWithBlockSampledDatalake(
            datalake,
            computationalTask4,
            24
        );

        // Compute commitment of the datalake and the task
        bytes32 datalakeCommitment = datalake.commit();
        bytes32 task1Commitment = computationalTask1.commit(datalakeCommitment);
        bytes32 task2Commitment = computationalTask2.commit(datalakeCommitment);
        bytes32 task3Commitment = computationalTask3.commit(datalakeCommitment);
        bytes32 task4Commitment = computationalTask4.commit(datalakeCommitment);

        // Check if the task state is PENDING
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

        // Encode datalakes
        bytes[] memory encodedDatalakes = new bytes[](4);
        encodedDatalakes[0] = datalake.encode();
        encodedDatalakes[1] = datalake.encode();
        encodedDatalakes[2] = datalake.encode();
        encodedDatalakes[3] = datalake.encode();

        // Encode tasks
        bytes[] memory computationalTasksSerialized = new bytes[](4);
        computationalTasksSerialized[0] = computationalTask1.encode();
        console.logBytes(computationalTasksSerialized[0]);
        computationalTasksSerialized[1] = computationalTask2.encode();
        console.logBytes(computationalTasksSerialized[1]);
        computationalTasksSerialized[2] = computationalTask3.encode();
        console.logBytes(computationalTasksSerialized[2]);
        computationalTasksSerialized[3] = computationalTask4.encode();
        console.logBytes(computationalTasksSerialized[3]);

        // =================================

        // (bytes32 tasksRoot, bytes32 resultsRoot) = processBatchThroughFFI(
        //     encodedDatalakes,
        //     computationalTasksSerialized
        // );

        bytes32 tasksRoot = 0x3e9e89351322b1e2dce3a766303f50797d6faeaf58d4175eaaa519770453a4f1;
        bytes32 resultsRoot = 0x147ed0b4f5fe3b4fed7db00142e639de72fa741b40355898d2f66996cd557bbb;

        uint256 tasksRootUint = uint256(tasksRoot);
        (uint256 tasksRootLow, uint256 tasksRootHigh) = Uint256Splitter
            .split128(tasksRootUint);

        uint256 resultsRootUint = uint256(resultsRoot);
        (uint256 resultsRootLow, uint256 resultsRootHigh) = Uint256Splitter
            .split128(resultsRootUint);

        // Output from Cairo Program
        uint256 usedMmrId = 24;
        uint256 usedMmrSize = 209371;
        // root of tasks merkle tree
        uint128 scheduledTasksBatchMerkleRootLow = uint128(tasksRootLow);
        uint128 scheduledTasksBatchMerkleRootHigh = uint128(tasksRootHigh);
        // root of result merkle tree
        uint128 batchResultsMerkleRootLow = uint128(resultsRootLow);
        uint128 batchResultsMerkleRootHigh = uint128(resultsRootHigh);

        // Fetch from Rust HDP
        // proof of the task
        bytes32[][] memory batchInclusionMerkleProofOfTasks = new bytes32[][](
            4
        );
        bytes32[] memory InclusionMerkleProofOfTask1 = new bytes32[](2);
        InclusionMerkleProofOfTask1[
            0
        ] = 0xdaeb56b4fed841576996ff1710a1fa0f1b2f8a4ff73c3b0b1453db93bd7868e5;
        InclusionMerkleProofOfTask1[
            1
        ] = 0x185ef0e2af28c57afed0f4d0a2f4c1d8a5d91a303819c13fd7847b213fb25aaf;
        batchInclusionMerkleProofOfTasks[0] = InclusionMerkleProofOfTask1;
        bytes32[] memory InclusionMerkleProofOfTask2 = new bytes32[](2);
        InclusionMerkleProofOfTask2[
            0
        ] = 0x6019bcfc2e4ee019364f70c25f2632f52babb5875780e62ed5f5fdf09fbc361c;
        InclusionMerkleProofOfTask2[
            1
        ] = 0x185ef0e2af28c57afed0f4d0a2f4c1d8a5d91a303819c13fd7847b213fb25aaf;
        batchInclusionMerkleProofOfTasks[1] = InclusionMerkleProofOfTask2;
        bytes32[] memory InclusionMerkleProofOfTask3 = new bytes32[](2);
        InclusionMerkleProofOfTask3[
            0
        ] = 0xefe80ee09ad6352ebb1bc03ce4be55ba8ba5660d992478647a1e9a5d85739c14;
        InclusionMerkleProofOfTask3[
            1
        ] = 0x200418e5706f9ef2e6bc3795371df8a00aa8076a7f57b24ec9f434a39a997511;
        batchInclusionMerkleProofOfTasks[2] = InclusionMerkleProofOfTask3;
        bytes32[] memory InclusionMerkleProofOfTask4 = new bytes32[](2);
        InclusionMerkleProofOfTask4[
            0
        ] = 0x83e5c05e645f433031b3c2123d7ec5ac00262571c5ed8e8af486c9e9784b46e2;
        InclusionMerkleProofOfTask4[
            1
        ] = 0x200418e5706f9ef2e6bc3795371df8a00aa8076a7f57b24ec9f434a39a997511;
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
        ] = 0x9a288c7072b2704bd59780c0d78e287451a0a942976d54278b5633d34c05003a;
        batchInclusionMerkleProofOfResults[0] = InclusionMerkleProofOfResult1;
        bytes32[] memory InclusionMerkleProofOfResult2 = new bytes32[](2);
        InclusionMerkleProofOfResult2[
            0
        ] = 0x30979630f4683a16bbaa655005717e678488bf03648fb99df9719f45506878d2;
        InclusionMerkleProofOfResult2[
            1
        ] = 0x76ea4d4b233cc5d64c4c20890f455d26714a137d278745db622a53aed4fce786;
        batchInclusionMerkleProofOfResults[1] = InclusionMerkleProofOfResult2;
        bytes32[] memory InclusionMerkleProofOfResult3 = new bytes32[](2);
        InclusionMerkleProofOfResult3[
            0
        ] = 0x64e5fda40eb8f1bd3e6fcaf42b6c51be9df9e316b8161d279b837962bedd2050;
        InclusionMerkleProofOfResult3[
            1
        ] = 0xb2b545f46a4e0cebf7c9f807092c655250ee3ed393deaf8b7d5dc76b30c06680;
        batchInclusionMerkleProofOfResults[2] = InclusionMerkleProofOfResult3;
        bytes32[] memory InclusionMerkleProofOfResult4 = new bytes32[](2);
        InclusionMerkleProofOfResult4[
            0
        ] = 0xa453776e9580b25b9117a8eb1ed970f4b3e01998e947561f253108749d1cf4a8;
        InclusionMerkleProofOfResult4[
            1
        ] = 0xb2b545f46a4e0cebf7c9f807092c655250ee3ed393deaf8b7d5dc76b30c06680;
        batchInclusionMerkleProofOfResults[3] = InclusionMerkleProofOfResult4;

        bytes32[] memory computationalTasksResult = new bytes32[](4);
        computationalTasksResult[0] = bytes32(uint256(17000000000000000000));
        computationalTasksResult[1] = bytes32(uint256(1180000000000000000000));
        computationalTasksResult[2] = bytes32(uint256(10000000000000000000));
        computationalTasksResult[3] = bytes32(uint256(11683168316831682560));

        // Testing purpose, insert the fact into the registry
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
            computationalTasksSerialized,
            computationalTasksResult
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

    function getFactHash(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh
    ) internal returns (bytes32) {
        // Load MMRs root
        bytes32 usedMmrRoot = hdp.loadMmrRoot(usedMmrId, usedMmrSize);
        console.logBytes32(usedMmrRoot);
        // Initialize an array of uint256 to store the program output
        uint256[] memory programOutput = new uint256[](6);

        // Assign values to the program output array
        programOutput[0] = uint256(usedMmrRoot);
        console.logBytes32(usedMmrRoot);
        programOutput[1] = uint256(usedMmrSize);
        console.logUint(usedMmrSize);
        programOutput[2] = uint256(batchResultsMerkleRootLow);
        console.logUint(batchResultsMerkleRootLow);
        programOutput[3] = uint256(batchResultsMerkleRootHigh);
        console.logUint(batchResultsMerkleRootHigh);
        programOutput[4] = uint256(scheduledTasksBatchMerkleRootLow);
        console.logUint(scheduledTasksBatchMerkleRootLow);
        programOutput[5] = uint256(scheduledTasksBatchMerkleRootHigh);
        console.logUint(scheduledTasksBatchMerkleRootHigh);

        // Compute program output hash
        bytes32 programOutputHash = keccak256(abi.encode(programOutput));

        // Compute GPS fact hash
        bytes32 gpsFactHash = keccak256(
            abi.encode(
                bytes32(
                    uint256(
                        0x1e0a58cc90bb6708f3c36a9cc503ffdcc3488b9aa57ccdbf0c18ae69d1c76ea
                    )
                ),
                programOutputHash
            )
        );

        return gpsFactHash;
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

    //     // Concatenate all elements into two big hexadecimal strings
    //     // TODO:not
    //     // string memory datalakesHex = Utf8ToHexString.concatenateBytesArray(
    //     //     encodedDatalakes
    //     // );
    //     // string memory tasksHex = Utf8ToHexString.concatenateBytesArray(
    //     //     encodedComputationalTasks
    //     // );

    //     string[] memory inputsExtended = new string[](5);
    //     // TODO: not generalized path
    //     inputsExtended[0] = "/Users/piapark/.cargo/bin/hdp";
    //     inputsExtended[1] = "run";
    //     inputsExtended[
    //         2
    //     ] = "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000060617667000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006073756d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000606d696e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000606d6178000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000";
    //     inputsExtended[
    //         3
    //     ] = "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001800000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000038000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002010f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002010f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002010f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009eb09c00000000000000000000000000000000000000000000000000000000009eb100000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000002010f000000000000000000000000000000000000000000000000000000000000";
    //     inputsExtended[
    //         4
    //     ] = "https://eth-goerli.g.alchemy.com/v2/OcJWF4RZDjyeCWGSmWChIlMEV28LtA5c";

    //     bytes memory outputExtended = vm.ffi(inputsExtended);
    //     console.logBytes(outputExtended);
    // }
}
