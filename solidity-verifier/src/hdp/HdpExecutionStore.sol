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
import {HexStringConverter} from "../lib/HexStringConverter.sol";

/// @title HdpExecutionStore
/// @author Herodotus Dev
/// @notice A contract to store the execution results of HDP tasks
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

    /// @notice emitted when a new MMR root is cached
    event MmrRootCached(uint256 mmrId, uint256 mmrSize, bytes32 mmrRoot);

    /// @notice emitted when a new task is scheduled
    event TaskWithBlockSampledDatalakeScheduled(BlockSampledDatalake datalake, ComputationalTask task);

    /// @notice constant representing role of operator
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice constant representing the hash of the Cairo HDP program
    bytes32 public constant PROGRAM_HASH = 0x001c8cc7762ed906ffd62867aa102adce05db50358a0224524f657ef23d0b7a5;

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
    /// @param blockSampledDatalake The block sampled datalake
    /// @param computationalTask The computational task
    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask
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

        emit TaskWithBlockSampledDatalakeScheduled(
            blockSampledDatalake,
            computationalTask
        );
    }

    /// @notice Authenticates the execution of a task is finalized
    ///     by verifying the FactRegistry and Merkle proofs
    /// @param usedMmrId The id of the MMR used to compute task
    /// @param usedMmrSize The size of the MMR used to compute task
    /// @param batchResultsMerkleRootLow The low 128 bits of the results Merkle root
    /// @param batchResultsMerkleRootHigh The high 128 bits of the results Merkle root
    /// @param scheduledTasksBatchMerkleRootLow The low 128 bits of the tasks Merkle root
    /// @param scheduledTasksBatchMerkleRootHigh The high 128 bits of the tasks Merkle root
    /// @param batchInclusionMerkleProofOfTasks The Merkle proof of the tasks
    /// @param batchInclusionMerkleProofOfResults The Merkle proof of the results
    /// @param computationalTasksResult The result of the computational tasks
    /// @param taskCommitments The commitment of the tasks
    function authenticateTaskExecution(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh,
        bytes32[][] memory batchInclusionMerkleProofOfTasks,
        bytes32[][] memory batchInclusionMerkleProofOfResults,
        bytes32[] calldata computationalTasksResult,
        bytes32[] calldata taskCommitments
    ) external onlyOperator {
        // Load MMRs root
        bytes32 usedMmrRoot = loadMmrRoot(usedMmrId, usedMmrSize);

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
        bytes32 gpsFactHash = keccak256(
            abi.encode(PROGRAM_HASH, programOutputHash)
        );

        // Ensure GPS fact is registered
        require(
            SHARP_FACTS_REGISTRY.isValid(gpsFactHash),
            "HdpExecutionStore: GPS fact is not registered"
        );

        // Loop through all the tasks in the batch
        for (uint256 i = 0; i < computationalTasksResult.length; i++) {
            bytes32 computationalTaskResult = computationalTasksResult[i];
            bytes32[]
                memory batchInclusionMerkleProofOfTask = batchInclusionMerkleProofOfTasks[
                    i
                ];
            bytes32[]
                memory batchInclusionMerkleProofOfResult = batchInclusionMerkleProofOfResults[
                    i
                ];

            // Convert the low and high 128 bits to a single 256 bit value
            bytes32 batchResultsMerkleRoot = bytes32(
                (uint256(batchResultsMerkleRootHigh) << 128) |
                    uint256(batchResultsMerkleRootLow)
            );
            bytes32 scheduledTasksBatchMerkleRoot = bytes32(
                (uint256(scheduledTasksBatchMerkleRootHigh) << 128) |
                    uint256(scheduledTasksBatchMerkleRootLow)
            );

            // Compute the Merkle leaf of the task
            bytes32 taskCommitment = taskCommitments[i];
            bytes32 taskMerkleLeaf = standardLeafHash(
                HexStringConverter.toHex(taskCommitment)
            );
            // Ensure that the task is included in the batch, by verifying the Merkle proof
            bool isVerifiedTask = batchInclusionMerkleProofOfTask.verify(
                scheduledTasksBatchMerkleRoot,
                taskMerkleLeaf
            );
            require(
                isVerifiedTask,
                "HdpExecutionStore: task is not included in the batch"
            );

            // Compute the Merkle leaf of the task result
            bytes32 taskResultCommitment = keccak256(
                abi.encode(taskCommitment, computationalTaskResult)
            );
            bytes32 taskResultMerkleLeaf = standardLeafHash(
                HexStringConverter.toHex(taskResultCommitment)
            );
            // Ensure that the task result is included in the batch, by verifying the Merkle proof
            bool isVerifiedResult = batchInclusionMerkleProofOfResult.verify(
                batchResultsMerkleRoot,
                taskResultMerkleLeaf
            );
            require(
                isVerifiedResult,
                "HdpExecutionStore: task result is not included in the batch"
            );

            // Store the task result
            cachedTasksResult[taskCommitment] = TaskResult({
                status: TaskStatus.FINALIZED,
                result: computationalTaskResult
            });
        }
    }

    /// @notice Load MMR root from cache with given mmrId and mmrSize
    function loadMmrRoot(
        uint256 mmrId,
        uint256 mmrSize
    ) public view returns (bytes32) {
        return cachedMMRsRoots[mmrId][mmrSize];
    }

    /// @notice Returns the result of a finalized task
    function getFinalizedTaskResult(
        bytes32 taskCommitment
    ) external view returns (bytes32) {
        // Ensure task is finalized
        require(
            cachedTasksResult[taskCommitment].status == TaskStatus.FINALIZED,
            "HdpExecutionStore: task is not finalized"
        );
        return cachedTasksResult[taskCommitment].result;
    }

    /// @notice Returns the status of a task
    function getTaskStatus(
        bytes32 taskCommitment
    ) external view returns (TaskStatus) {
        return cachedTasksResult[taskCommitment].status;
    }

    /// @notice Returns the leaf of standard merkle tree
    function standardLeafHash(
        string memory value
    ) public pure returns (bytes32) {
        bytes32 firstHash = keccak256(abi.encode(value));
        bytes32 leaf = keccak256(abi.encode(firstHash));
        return leaf;
    }
}
