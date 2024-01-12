// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import {IFactsRegistry} from "./interfaces/IFactsRegistry.sol";

contract HreExecutionStore is AccessControl {
    using MerkleProof for bytes32[];

    // Structs specific to the HRE execution
    struct BlockSampledDatalake {
        uint256 blockRangeStart;
        uint256 blockRangeEnd;
        uint256 sampledProperty;
        uint256 increment;
    }

    struct IterativeDynamicLayoutDatalake {
        uint256 blockNumber;
        address account;
        uint256 slotIndex;
        uint256 initialKey;
        uint256 keyBoundry;
        uint256 increment;
    }

    struct ComputationalTask {
        bytes32 datalakeCommitment;
        uint256 aggregateFnId;
        bytes aggregateFnCtx;
    }

    // Persistent struct
    enum TaskState {
        NONE,
        SCHEDULED,
        FINALIZED
    }
    struct TaskInfo {
        TaskState state;
        bytes result;
    }

    // Roles
    bytes32 public constant PROVER_ROLE = keccak256("PROVER_ROLE");

    // Sharp Facts Registry
    IFactsRegistry public immutable FACTS_REGISTRY;

    mapping(bytes32 => TaskInfo) public computationalTaskResults;

    bytes32 public constant PROGRAM_HASH =
        bytes32(
            uint256(
                0x01eca36d586f5356fba096edbf7414017d51cd0ed24b8fde80f78b61a9216ed2
            )
        );

    constructor(IFactsRegistry factsRegistry) {
        FACTS_REGISTRY = factsRegistry;
    }

    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask
    ) external {
        bytes memory serializedDatalakeHeader = abi.encode(
            blockSampledDatalake.blockRangeStart,
            blockSampledDatalake.blockRangeEnd,
            blockSampledDatalake.sampledProperty,
            blockSampledDatalake.increment
        );
        bytes32 datalakeCommitment = keccak256(serializedDatalakeHeader);

        // Ensure that the computed datalake commitment matches the one in the task
        require(
            datalakeCommitment == computationalTask.datalakeCommitment,
            "HreExecutionStore: datalake commitment mismatch"
        );

        // TODO actually serialize it
        bytes memory computationalTaskSerialized = abi.encode(
            blockSampledDatalake,
            computationalTask
        );
        bytes32 taskHash = keccak256(computationalTaskSerialized);

        // Ensure task is not already scheduled
        require(
            computationalTaskResults[taskHash].state == TaskState.NONE,
            "HreExecutionStore: task is already scheduled"
        );

        // Store the task
        computationalTaskResults[taskHash] = TaskInfo({
            state: TaskState.SCHEDULED,
            result: ""
        });
    }

    function authenticateTaskExecution(
        uint256 usedMMRsIdsPacked,
        bytes32 scheduledTasksBatchMerkleRoot,
        bytes32 batchResultsMerkleRoot,
        bytes32[] memory batchInclusionMerkleProofOfTask,
        bytes32[] memory batchInclusionMerkleProofOfResult,
        bytes calldata computationalTaskSerialized,
        bytes calldata computationalTaskResult
    ) external {
        // Ensure caller is the "Prover"
        require(
            hasRole(PROVER_ROLE, msg.sender),
            "HreExecutionStore: caller is not the Prover"
        );

        // Compute GPS fact hash
        bytes32 gpsFactHash = keccak256(
            abi.encode(
                PROGRAM_HASH,
                usedMMRsIdsPacked,
                scheduledTasksBatchMerkleRoot,
                batchResultsMerkleRoot
            )
        );
        // Ensure GPS fact is registered
        require(
            FACTS_REGISTRY.isValid(gpsFactHash),
            "HreExecutionStore: GPS fact is not registered"
        );

        // Ensure that the task is included in the batch, by verifying the Merkle proof
        bytes32 taskHash = keccak256(computationalTaskSerialized);
        batchInclusionMerkleProofOfTask.verify(
            scheduledTasksBatchMerkleRoot,
            taskHash
        );

        // Ensure that the task result is included in the batch, by verifying the Merkle proof
        bytes32 taskResultHash = keccak256(
            abi.encode(taskHash, computationalTaskResult)
        );
        batchInclusionMerkleProofOfResult.verify(
            batchInclusionMerkleProofOfResult,
            taskResultHash
        );

        // TODO verify merkle proof

        // Store the task result
        computationalTaskResults[taskHash] = TaskInfo({
            state: TaskState.FINALIZED,
            result: computationalTaskResult
        });
    }
}
