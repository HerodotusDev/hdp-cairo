// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {MerkleProof} from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

import {IFactsRegistry} from "../interfaces/IFactsRegistry.sol";
import {ISharpFactsAggregator} from "../interfaces/ISharpFactsAggregator.sol";
import {IAggregatorsFactory} from "../interfaces/IAggregatorsFactory.sol";

import {BlockSampledDatalake, BlockSampledDatalakeCodecs} from "./datatypes/BlockSampledDatalakeCodecs.sol";
import {
    IterativeDynamicLayoutDatalake,
    IterativeDynamicLayoutDatalakeCodecs
} from "./datatypes/IterativeDynamicLayoutDatalakeCodecs.sol";
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

    // Roles
    bytes32 public constant PROVER_ROLE = keccak256("PROVER_ROLE");

    bytes32 public constant PROGRAM_HASH =
        bytes32(uint256(0x01eca36d586f5356fba096edbf7414017d51cd0ed24b8fde80f78b61a9216ed2));

    // Sharp Facts Registry
    IFactsRegistry public immutable FACTS_REGISTRY;
    IAggregatorsFactory public immutable AGGREGATORS_FACTORY;

    mapping(bytes32 => TaskInfo) public computationalTaskResults;

    // mmr_id => mmr_size => mmr_root
    mapping(uint256 => mapping(uint256 => bytes32)) public cachedMMRsRoots;

    constructor(IFactsRegistry factsRegistry, IAggregatorsFactory aggregatorsFactory) {
        FACTS_REGISTRY = factsRegistry;
        AGGREGATORS_FACTORY = aggregatorsFactory;
    }

    function cacheMmrRoot(uint256 mmrId) external {
        ISharpFactsAggregator aggregator = AGGREGATORS_FACTORY.aggregatorsById(mmrId);
        ISharpFactsAggregator.AggregatorState memory aggregatorState = aggregator.aggregatorState();
        cachedMMRsRoots[mmrId][aggregatorState.mmrSize] = aggregatorState.poseidonMmrRoot;
        emit MmrRootCached(mmrId, aggregatorState.mmrSize, aggregatorState.poseidonMmrRoot);
    }

    function requestExecutionOfTaskWithBlockSampledDatalake(
        BlockSampledDatalake calldata blockSampledDatalake,
        ComputationalTask calldata computationalTask,
        uint256 usedMMRsPacked
    ) external {
        bytes32 datalakeCommitment = blockSampledDatalake.commit();
        bytes32 taskCommitment = computationalTask.commit(datalakeCommitment);

        // Ensure task is not already scheduled
        require(
            computationalTaskResults[taskCommitment].state == TaskState.NONE,
            "HreExecutionStore: task is already scheduled"
        );

        // Store the task
        computationalTaskResults[taskCommitment] = TaskInfo({state: TaskState.SCHEDULED, result: ""});
        // Cache MMR roots used by the request
        bytes32[] memory usedMmrRoots = new bytes32[](4);
        for (uint256 i = 0; i < 4; i++) {
            uint256 mmrId = (usedMMRsPacked >> (i * 64)) & 0xffffffffffffffff;
            uint256 mmrSize = (usedMMRsPacked >> (i * 64 + 64)) & 0xffffffffffffffff;
            ISharpFactsAggregator aggregator = AGGREGATORS_FACTORY.aggregatorsById(mmrId);
            ISharpFactsAggregator.AggregatorState memory aggregatorState = aggregator.aggregatorState();
            cachedMMRsRoots[mmrId][aggregatorState.mmrSize] = aggregatorState.poseidonMmrRoot;
            emit MmrRootCached(mmrId, aggregatorState.mmrSize, aggregatorState.poseidonMmrRoot);
        }
    }

    function authenticateTaskExecution(
        uint256 usedMMRsPacked,
        bytes32 scheduledTasksBatchMerkleRoot,
        bytes32 batchResultsMerkleRoot,
        bytes32[] memory batchInclusionMerkleProofOfTask,
        bytes32[] memory batchInclusionMerkleProofOfResult,
        bytes calldata computationalTaskSerialized,
        bytes calldata computationalTaskResult
    ) external {
        // Ensure caller is the "Prover"
        require(hasRole(PROVER_ROLE, msg.sender), "HreExecutionStore: caller is not the Prover");

        // Load MMRs roots
        bytes32[] memory usedMmrRoots = _loadMmrRoots(usedMMRsPacked);

        // Compute GPS fact hash
        bytes32 gpsFactHash =
            keccak256(abi.encode(PROGRAM_HASH, usedMmrRoots, scheduledTasksBatchMerkleRoot, batchResultsMerkleRoot));
        // Ensure GPS fact is registered
        require(FACTS_REGISTRY.isValid(gpsFactHash), "HreExecutionStore: GPS fact is not registered");

        // Ensure that the task is included in the batch, by verifying the Merkle proof
        bytes32 taskHash = keccak256(computationalTaskSerialized);
        batchInclusionMerkleProofOfTask.verify(scheduledTasksBatchMerkleRoot, taskHash);

        // Ensure that the task result is included in the batch, by verifying the Merkle proof
        bytes32 taskResultHash = keccak256(abi.encode(taskHash, computationalTaskResult));
        batchInclusionMerkleProofOfResult.verify(batchResultsMerkleRoot, taskResultHash);

        // Store the task result
        computationalTaskResults[taskHash] = TaskInfo({state: TaskState.FINALIZED, result: computationalTaskResult});
    }

    function _loadMmrRoots(uint256 usedMMRsPacked) internal view returns (bytes32[] memory) {
        bytes32[] memory usedMmrRoots = new bytes32[](4);

        // Load MMRs roots
        for (uint256 i = 0; i < 4; i++) {
            uint256 mmrId = (usedMMRsPacked >> (i * 64)) & 0xffffffffffffffff;
            uint256 mmrSize = (usedMMRsPacked >> (i * 64 + 64)) & 0xffffffffffffffff;
            usedMmrRoots[i] = cachedMMRsRoots[mmrId][mmrSize];
        }

        return usedMmrRoots;
    }
}