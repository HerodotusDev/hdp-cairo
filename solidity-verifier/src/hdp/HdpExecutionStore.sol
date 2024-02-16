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

    // Events
    event MmrRootCached(uint256 mmrId, uint256 mmrSize, bytes32 mmrRoot);

    // Access control
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    bytes32 public constant PROGRAM_HASH =
        bytes32(
            uint256(
                0x01eca36d586f5356fba096edbf7414017d51cd0ed24b8fde80f78b61a9216ed2
            )
        );

    // Sharp Facts Registry
    IFactsRegistry public immutable FACTS_REGISTRY;
    IAggregatorsFactory public immutable AGGREGATORS_FACTORY;

    mapping(bytes32 => TaskInfo) public computationalTaskResults;

    // mmr_id => mmr_size => mmr_root
    mapping(uint256 => mapping(uint256 => bytes32)) public cachedMMRsRoots;

    /// Create a new HdpExecutionStore and grants OPERATOR_ROLE to the deployer
    constructor(
        IFactsRegistry factsRegistry,
        IAggregatorsFactory aggregatorsFactory
    ) {
        FACTS_REGISTRY = factsRegistry;
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

    function _cacheMmrRoot(uint256 mmrId) internal {
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

    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask,
        uint256 usedMMRId
    ) external {
        bytes32 datalakeCommitment = blockSampledDatalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        // Ensure task is not already scheduled
        require(
            computationalTaskResults[taskCommitment].state == TaskState.NONE,
            "HreExecutionStore: task is already scheduled"
        );

        // Store the task
        computationalTaskResults[taskCommitment] = TaskInfo({
            state: TaskState.SCHEDULED,
            result: ""
        });

        // Cache MMR root
        _cacheMmrRoot(usedMMRId);
    }

    function authenticateTaskExecution(
        uint256 usedMmrId,
        uint256 usedMmrSize,
        uint128 batchResultsMerkleRootLow,
        uint128 batchResultsMerkleRootHigh,
        uint128 scheduledTasksBatchMerkleRootLow,
        uint128 scheduledTasksBatchMerkleRootHigh,
        bytes32[] memory batchInclusionMerkleProofOfTask,
        bytes32[] memory batchInclusionMerkleProofOfResult,
        bytes[] calldata computationalTasksSerialized,
        bytes[] calldata computationalTasksResult
    ) external onlyOperator {
        // Load MMRs roots
        // TODO: How to get mmr size if cairo hdp not outputting it
        bytes32 usedMmrRoot = _loadMmrRoot(usedMmrId, usedMmrSize);

        // Loop through all the tasks in the batch
        for (uint256 i = 0; i < computationalTasksSerialized.length; i++) {
            bytes
                memory computationalTaskSerialized = computationalTasksSerialized[
                    i
                ];
            bytes memory computationalTaskResult = computationalTasksResult[i];

            // Initialize an array of uint256 to store the program output
            uint256[] memory programOutput = new uint256[](5);

            // Assign values to the program output array
            programOutput[0] = uint256(usedMmrRoot);
            programOutput[1] = uint256(batchResultsMerkleRootLow);
            programOutput[2] = uint256(batchResultsMerkleRootHigh);
            programOutput[3] = uint256(scheduledTasksBatchMerkleRootLow);
            programOutput[4] = uint256(scheduledTasksBatchMerkleRootHigh);

            // Compute program output hash
            bytes32 programOutputHash = keccak256(abi.encode(programOutput));

            // Compute GPS fact hash
            bytes32 gpsFactHash = keccak256(
                abi.encode(PROGRAM_HASH, programOutputHash)
            );

            // Ensure GPS fact is registered
            require(
                FACTS_REGISTRY.isValid(gpsFactHash),
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
            computationalTaskResults[taskHash] = TaskInfo({
                state: TaskState.FINALIZED,
                result: computationalTaskResult
            });
        }
    }

    // TODO: For sake of simplicity, we assume N tasks are included in 1 MMR for V1
    function _loadMmrRoots(
        uint256 usedMMRsPacked
    ) internal view returns (bytes32[] memory) {
        bytes32[] memory usedMmrRoots = new bytes32[](4);

        // Load MMRs roots
        for (uint256 i = 0; i < 4; i++) {
            uint256 mmrId = (usedMMRsPacked >> (i * 64)) & 0xffffffffffffffff;
            uint256 mmrSize = (usedMMRsPacked >> (i * 64 + 64)) &
                0xffffffffffffffff;
            usedMmrRoots[i] = cachedMMRsRoots[mmrId][mmrSize];
        }

        return usedMmrRoots;
    }

    // Load MMR root from cache with given mmrId and mmrSize
    function _loadMmrRoot(
        uint256 mmrId,
        uint256 mmrSize
    ) internal view returns (bytes32) {
        return cachedMMRsRoots[mmrId][mmrSize];
    }
}
