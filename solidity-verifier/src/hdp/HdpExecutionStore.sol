// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {IFactsRegistry} from "../interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../interfaces/IAggregatorsFactory.sol";

import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "./datatypes/BlockSampledDatalakeCodecs.sol";
import {IterativeDynamicLayoutDatalake, IterativeDynamicLayoutDatalakeCodecs} from "./datatypes/IterativeDynamicLayoutDatalakeCodecs.sol";
import {ComputationalTask, ComputationalTaskCodecs} from "./datatypes/ComputationalTaskCodecs.sol";

contract HdpExecutionStore is AccessControl {
    using MerkleProof for bytes32[];
    using BlockSampledDatalakeCodecs for BlockSampledDatalake;
    using IterativeDynamicLayoutDatalakeCodecs for IterativeDynamicLayoutDatalake;
    using ComputationalTaskCodecs for ComputationalTask;

    /// @notice The status of a task
    enum TaskStatus {
        NONE,
        SCHEDULED,
        FINALIZED
    }

    /// @notice The struct representing a task result
    struct TaskResult {
        TaskStatus status;
        bytes32 result;
    }

    /// @notice emitted when a new task is scheduled
    event MmrRootCached(uint256 mmrId, uint256 mmrSize, bytes32 mmrRoot);

    /// @notice constant representing role of operator
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice constant representing the hash of the Cairo HDP program
    bytes32 public constant PROGRAM_HASH =
        bytes32(
            uint256(
                0x1e0a58cc90bb6708f3c36a9cc503ffdcc3488b9aa57ccdbf0c18ae69d1c76ea
            )
        );

    /// @notice interface to the facts registry of SHARP
    IFactsRegistry public immutable SHARP_FACTS_REGISTRY;

    /// @notice interface to the aggregators factory
    IAggregatorsFactory public immutable AGGREGATORS_FACTORY;

    /// @notice mapping of task result hash => task
    mapping(bytes32 => TaskResult) public cachedTasksResult;

    /// @notice mapping of mmr id => mmr size => mmr root
    mapping(uint256 => mapping(uint256 => bytes32)) public cachedMMRsRoots;

    constructor(
        IFactsRegistry factsRegistry,
        IAggregatorsFactory aggregatorsFactory
    ) {
        SHARP_FACTS_REGISTRY = factsRegistry;
        AGGREGATORS_FACTORY = aggregatorsFactory;

        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE);
        _grantRole(OPERATOR_ROLE, _msgSender());
    }

    /// @notice Reverts if the caller is not an operator
    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Caller is not an operator"
        );
        _;
    }

    /// @notice Caches the MMR root for a given MMR id
    /// @notice Get MMR size and root from the aggregator and cache it
    function cacheMmrRoot(uint256 mmrId) public {
        ISharpFactsAggregator aggregator = AGGREGATORS_FACTORY.aggregatorsById(
            mmrId
        );
        ISharpFactsAggregator.AggregatorState
            memory aggregatorState = aggregator.aggregatorState();
        cachedMMRsRoots[mmrId][aggregatorState.mmrSize] = aggregatorState
            .poseidonMmrRoot;

        emit MmrRootCached(
            mmrId,
            aggregatorState.mmrSize,
            aggregatorState.poseidonMmrRoot
        );
    }

    /// @notice Requests the execution of a task with a block sampled datalake
    /// @param usedMmrId The MMR id used to compute task
    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask,
        uint256 usedMmrId
    ) external {
        bytes32 datalakeCommitment = blockSampledDatalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        // Ensure task is not already scheduled
        require(
            cachedTasksResult[taskCommitment].status == TaskStatus.NONE,
            "HreExecutionStore: task is already scheduled"
        );

        // Store the task result
        cachedTasksResult[taskCommitment] = TaskResult({
            status: TaskStatus.SCHEDULED,
            result: ""
        });

        // Cache MMR root
        cacheMmrRoot(usedMmrId);
    }

    function authenticateTaskExecution(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh,
        bytes32[][] memory batchInclusionMerkleProofOfTasks,
        bytes32[][] memory batchInclusionMerkleProofOfResults,
        bytes[] calldata computationalTasksSerialized,
        bytes32[] calldata computationalTasksResult
    ) external onlyOperator {
        // Load MMRs root
        bytes32 usedMmrRoot = _loadMmrRoot(usedMmrId, usedMmrSize);

        // Loop through all the tasks in the batch
        for (uint256 i = 0; i < computationalTasksSerialized.length; i++) {
            bytes
                memory computationalTaskSerialized = computationalTasksSerialized[
                    i
                ];
            bytes32 computationalTaskResult = computationalTasksResult[i];
            bytes32[]
                memory batchInclusionMerkleProofOfTask = batchInclusionMerkleProofOfTasks[
                    i
                ];
            bytes32[]
                memory batchInclusionMerkleProofOfResult = batchInclusionMerkleProofOfResults[
                    i
                ];

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
                abi.encode(PROGRAM_HASH, programOutputHash)
            );

            // Ensure GPS fact is registered
            require(
                SHARP_FACTS_REGISTRY.isValid(gpsFactHash),
                "HdpExecutionStore: GPS fact is not registered"
            );

            // Encode result merkle root
            bytes32 batchResultsMerkleRoot = bytes32(
                (uint256(batchResultsMerkleRootHigh) << 128) |
                    uint256(batchResultsMerkleRootLow)
            );

            bytes32 scheduledTasksBatchMerkleRoot = bytes32(
                (uint256(scheduledTasksBatchMerkleRootHigh) << 128) |
                    uint256(scheduledTasksBatchMerkleRootLow)
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
                batchResultsMerkleRoot,
                taskResultHash
            );

            // Store the task result
            cachedTasksResult[taskResultHash] = TaskResult({
                status: TaskStatus.FINALIZED,
                result: computationalTaskResult
            });
        }
    }

    /// @notice Load MMR root from cache with given mmrId and mmrSize
    function _loadMmrRoot(
        uint256 mmrId,
        uint256 mmrSize
    ) internal view returns (bytes32) {
        return cachedMMRsRoots[mmrId][mmrSize];
    }

    /// @notice Returns the result of a finalized task
    function getFinalizedTaskResult(
        bytes32 taskResultHash
    ) external view returns (bytes32) {
        // Ensure task is finalized
        require(
            cachedTasksResult[taskResultHash].status == TaskStatus.FINALIZED,
            "HdpExecutionStore: task is not finalized"
        );
        return cachedTasksResult[taskResultHash].result;
    }

    /// @notice Returns the status of a task
    function getTaskStatus(
        bytes32 taskResultHash
    ) external view returns (TaskStatus) {
        return cachedTasksResult[taskResultHash].status;
    }
}
