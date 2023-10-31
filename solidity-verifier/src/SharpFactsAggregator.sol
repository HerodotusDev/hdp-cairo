// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";

import {IFactsRegistry} from "./interfaces/IFactsRegistry.sol";
import {Uint256Splitter} from "./lib/Uint256Splitter.sol";

/// @title SharpFactsAggregator
/// @dev Aggregator contract to handle SHARP job outputs and update the global aggregator state.
/// @author Herodotus Dev
/// ------------------
/// Example:
/// Blocks inside brackets are the ones processed during their SHARP job execution
//  7 [8 9 10] 11
/// n = 10
/// r = 3
/// `r` is the number of blocks processed on a single SHARP job execution
/// `blockNMinusRPlusOneParentHash` = 8.parentHash (oldestHash)
/// `blockNPlusOneParentHash`       = 11.parentHash (newestHash)
/// ------------------
contract SharpFactsAggregator is Initializable, AccessControlUpgradeable {
    // Using inline library for efficient splitting and joining of uint256 values
    using Uint256Splitter for uint256;

    // Role definitions for access control
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UNLOCKER_ROLE = keccak256("UNLOCKER_ROLE");

    uint256 public constant MINIMUM_BLOCKS_CONFIRMATIONS = 20;
    uint256 public constant MAXIMUM_BLOCKS_CONFIRMATIONS = 255;

    // Sharp Facts Registry
    IFactsRegistry public immutable FACTS_REGISTRY;

    // Cairo program hash (i.e., the off-chain block headers accumulator program)
    bytes32 public constant PROGRAM_HASH =
        bytes32(
            uint256(
                0x01eca36d586f5356fba096edbf7414017d51cd0ed24b8fde80f78b61a9216ed2
            )
        );

    // Global aggregator state
    struct AggregatorState {
        bytes32 poseidonMmrRoot;
        bytes32 keccakMmrRoot;
        uint256 mmrSize;
        bytes32 continuableParentHash;
    }

    // Current __global__ state of this aggregator
    AggregatorState public aggregatorState;

    // Mapping to keep track of block number to its parent hash
    mapping(uint256 => bytes32) public blockNumberToParentHash;

    // Flag to control operator role requirements
    bool public isOperatorRequired;

    // Representation of the Cairo program's output (raw unpacked)
    struct JobOutput {
        uint256 fromBlockNumberHigh;
        uint256 toBlockNumberLow;
        bytes32 blockNPlusOneParentHashLow;
        bytes32 blockNPlusOneParentHashHigh;
        bytes32 blockNMinusRPlusOneParentHashLow;
        bytes32 blockNMinusRPlusOneParentHashHigh;
        bytes32 mmrPreviousRootPoseidon;
        bytes32 mmrPreviousRootKeccakLow;
        bytes32 mmrPreviousRootKeccakHigh;
        uint256 mmrPreviousSize;
        bytes32 mmrNewRootPoseidon;
        bytes32 mmrNewRootKeccakLow;
        bytes32 mmrNewRootKeccakHigh;
        uint256 mmrNewSize;
    }

    // Packed representation of the Cairo program's output (for gas efficiency)
    struct JobOutputPacked {
        uint256 blockNumbersPacked;
        bytes32 blockNPlusOneParentHash;
        bytes32 blockNMinusRPlusOneParentHash;
        bytes32 mmrPreviousRootPoseidon;
        bytes32 mmrPreviousRootKeccak;
        bytes32 mmrNewRootPoseidon;
        bytes32 mmrNewRootKeccak;
        uint256 mmrSizesPacked;
    }

    // Custom errors for better error handling and clarity
    error NotEnoughBlockConfirmations();
    error TooManyBlocksConfirmations();
    error NotEnoughJobs();
    error UnknownParentHash();
    error AggregationError(string message); // Generic error with a message
    error AggregationBlockMismatch();
    error GenesisBlockReached();
    error InvalidFact();

    // Event emitted when a new range is registered
    // (i.e, when we want to allow aggregating from a more recent block)
    event NewRangeRegistered(
        uint256 targetBlock,
        bytes32 targetBlockParentHash
    );

    // Event emitted when __at least__ one SHARP job is aggregated
    event Aggregate(
        uint256 fromBlockNumberHigh,
        uint256 toBlockNumberLow,
        bytes32 poseidonMmrRoot,
        bytes32 keccakMmrRoot,
        uint256 mmrSize,
        bytes32 continuableParentHash
    );

    event OperatorRequirementChange(bool newRequirement);

    constructor(IFactsRegistry factsRegistry) {
        FACTS_REGISTRY = factsRegistry;
    }

    /**
     * @notice Initializes the contract with given parameters.
     * @param initialAggregatorState Initial state of the aggregator (i.e., initial trees state).
     */
    function initialize(
        AggregatorState calldata initialAggregatorState
    ) public initializer {
        __AccessControl_init();

        aggregatorState = initialAggregatorState;

        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE);
        _setRoleAdmin(UNLOCKER_ROLE, OPERATOR_ROLE);

        // Grant operator role to the contract deployer
        // to be able to define new aggregate ranges
        _grantRole(OPERATOR_ROLE, _msgSender());
        _grantRole(UNLOCKER_ROLE, _msgSender());

        // Set operator role requirement to true by default
        isOperatorRequired = true;
    }

    /// @notice Reverts if the caller is not an operator and the operator role requirement is enabled
    modifier onlyOperator() {
        if (isOperatorRequired) {
            require(
                hasRole(OPERATOR_ROLE, _msgSender()),
                "Caller is not an operator"
            );
        }
        _;
    }

    /// @notice Reverts if the caller is not an unlocker
    modifier onlyUnlocker() {
        require(
            hasRole(UNLOCKER_ROLE, _msgSender()),
            "Caller is not an unlocker"
        );
        _;
    }

    /// @dev Modifies the contract's operator requirement
    function setOperatorRequired(
        bool _isOperatorRequired
    ) external onlyUnlocker {
        isOperatorRequired = _isOperatorRequired;
        emit OperatorRequirementChange(_isOperatorRequired);
    }

    /// Registers a new range to aggregate from
    /// @notice Caches a recent block hash (MINIMUM_BLOCKS_CONFIRMATIONS to -MAXIMUM_BLOCKS_CONFIRMATIONS from present), relying on the global `blockhash` Solidity function
    /// @param blocksConfirmations Number of blocks preceding the current block
    function registerNewRange(
        uint256 blocksConfirmations
    ) external onlyOperator {
        // Minimum blocks confirmations to avoid reorgs
        if (blocksConfirmations < MINIMUM_BLOCKS_CONFIRMATIONS) {
            revert NotEnoughBlockConfirmations();
        }

        // Maximum MAXIMUM_BLOCKS_CONFIRMATIONS blocks confirmations to capture
        // an available block hash with Solidity `blockhash()`
        if (blocksConfirmations > MAXIMUM_BLOCKS_CONFIRMATIONS) {
            revert TooManyBlocksConfirmations();
        }

        // Determine the target block number (i.e. the child block)
        uint256 targetBlock = block.number - blocksConfirmations;

        // Extract its parent hash.
        bytes32 targetBlockParentHash = blockhash(targetBlock - 1);

        // If the parent hash is not available, revert
        // (This should never happen under the current EVM rules)
        if (targetBlockParentHash == bytes32(0)) {
            revert UnknownParentHash();
        }

        // Cache the parent hash so that we can later on continue accumlating from it
        blockNumberToParentHash[targetBlock] = targetBlockParentHash;

        // If we cannot aggregate further in the past (e.g., genesis block is reached or it's a new tree)
        if (aggregatorState.continuableParentHash == bytes32(0)) {
            // Set the aggregator state's `continuableParentHash` to the target block's parent hash
            // so we can easily continue aggregating from it without specifying `rightBoundStartBlock` in `aggregateSharpJobs`
            aggregatorState.continuableParentHash = targetBlockParentHash;
        }

        emit NewRangeRegistered(targetBlock, targetBlockParentHash);
    }

    /// @notice Aggregate SHARP jobs outputs (min. 1) to update the global aggregator state
    /// @param rightBoundStartBlock The reference block to start from. Defaults to continuing from the global state if set to `0`
    /// @param outputs Array of SHARP jobs outputs (packed for Solidity)
    function aggregateSharpJobs(
        uint256 rightBoundStartBlock,
        JobOutputPacked[] calldata outputs
    ) external onlyOperator {
        // Ensuring at least one job output is provided
        if (outputs.length < 1) {
            revert NotEnoughJobs();
        }

        bytes32 rightBoundStartBlockParentHash = bytes32(0);

        // Start from a different block than the current state if `rightBoundStartBlock` is specified
        if (rightBoundStartBlock != 0) {
            // Retrieve from cache the parent hash of the block to start from
            rightBoundStartBlockParentHash = blockNumberToParentHash[
                rightBoundStartBlock
            ];

            // If not present in the cache, hash is not authenticated and we cannot continue from it
            if (rightBoundStartBlockParentHash == bytes32(0)) {
                revert UnknownParentHash();
            }
        }

        JobOutputPacked calldata firstOutput = outputs[0];
        // Ensure the first job is continuable
        ensureContinuable(rightBoundStartBlockParentHash, firstOutput);

        if (rightBoundStartBlockParentHash != bytes32(0)) {
            (uint256 fromBlockHighStart, ) = firstOutput
                .blockNumbersPacked
                .split128();

            // We check that block numbers are consecutives
            if (fromBlockHighStart != rightBoundStartBlock - 1) {
                revert AggregationBlockMismatch();
            }
        }

        uint256 limit = outputs.length - 1;

        // Iterate over the jobs outputs (aside from the last one)
        // and ensure jobs are correctly linked and valid
        for (uint256 i = 0; i < limit; ++i) {
            JobOutputPacked calldata curOutput = outputs[i];
            JobOutputPacked calldata nextOutput = outputs[i + 1];

            ensureValidFact(curOutput);
            ensureConsecutiveJobs(curOutput, nextOutput);
        }

        JobOutputPacked calldata lastOutput = outputs[limit];
        ensureValidFact(lastOutput);

        // We save the latest output in the contract state for future calls
        (, uint256 mmrNewSize) = lastOutput.mmrSizesPacked.split128();
        aggregatorState.poseidonMmrRoot = lastOutput.mmrNewRootPoseidon;
        aggregatorState.keccakMmrRoot = lastOutput.mmrNewRootKeccak;
        aggregatorState.mmrSize = mmrNewSize;
        aggregatorState.continuableParentHash = lastOutput
            .blockNMinusRPlusOneParentHash;

        (uint256 fromBlock, ) = firstOutput.blockNumbersPacked.split128();
        (, uint256 toBlock) = lastOutput.blockNumbersPacked.split128();

        emit Aggregate(
            fromBlock,
            toBlock,
            lastOutput.mmrNewRootPoseidon,
            lastOutput.mmrNewRootKeccak,
            mmrNewSize,
            lastOutput.blockNMinusRPlusOneParentHash
        );
    }

    /// @notice Ensures the fact is registered on SHARP Facts Registry
    /// @param output SHARP job output (packed for Solidity)
    function ensureValidFact(JobOutputPacked memory output) internal view {
        (uint256 fromBlock, uint256 toBlock) = output
            .blockNumbersPacked
            .split128();

        (uint256 mmrPreviousSize, uint256 mmrNewSize) = output
            .mmrSizesPacked
            .split128();
        (
            uint256 blockNPlusOneParentHashLow,
            uint256 blockNPlusOneParentHashHigh
        ) = uint256(output.blockNPlusOneParentHash).split128();

        (
            uint256 blockNMinusRPlusOneParentHashLow,
            uint256 blockNMinusRPlusOneParentHashHigh
        ) = uint256(output.blockNMinusRPlusOneParentHash).split128();

        (
            uint256 mmrPreviousRootKeccakLow,
            uint256 mmrPreviousRootKeccakHigh
        ) = uint256(output.mmrPreviousRootKeccak).split128();

        (uint256 mmrNewRootKeccakLow, uint256 mmrNewRootKeccakHigh) = uint256(
            output.mmrNewRootKeccak
        ).split128();

        // We assemble the outputs in a uint256 array
        uint256[] memory outputs = new uint256[](14);
        outputs[0] = fromBlock;
        outputs[1] = toBlock;
        outputs[2] = blockNPlusOneParentHashLow;
        outputs[3] = blockNPlusOneParentHashHigh;
        outputs[4] = blockNMinusRPlusOneParentHashLow;
        outputs[5] = blockNMinusRPlusOneParentHashHigh;
        outputs[6] = uint256(output.mmrPreviousRootPoseidon);
        outputs[7] = mmrPreviousRootKeccakLow;
        outputs[8] = mmrPreviousRootKeccakHigh;
        outputs[9] = mmrPreviousSize;
        outputs[10] = uint256(output.mmrNewRootPoseidon);
        outputs[11] = mmrNewRootKeccakLow;
        outputs[12] = mmrNewRootKeccakHigh;
        outputs[13] = mmrNewSize;

        // We hash the outputs
        bytes32 outputHash = keccak256(abi.encodePacked(outputs));

        // We compute the deterministic fact bytes32 value
        bytes32 fact = keccak256(abi.encode(PROGRAM_HASH, outputHash));

        // We ensure this fact has been registered on SHARP Facts Registry
        if (!FACTS_REGISTRY.isValid(fact)) {
            revert InvalidFact();
        }
    }

    /// @notice Ensures the job output is cryptographically sound to continue from
    /// @param rightBoundStartParentHash The parent hash of the block to start from
    /// @param output The job output to check
    function ensureContinuable(
        bytes32 rightBoundStartParentHash,
        JobOutputPacked memory output
    ) internal view {
        (uint256 mmrPreviousSize, ) = output.mmrSizesPacked.split128();

        // Check that the job's previous Poseidon MMR root is the same as the one stored in the contract state
        if (output.mmrPreviousRootPoseidon != aggregatorState.poseidonMmrRoot)
            revert AggregationError("Poseidon root mismatch");

        // Check that the job's previous Keccak MMR root is the same as the one stored in the contract state
        if (output.mmrPreviousRootKeccak != aggregatorState.keccakMmrRoot)
            revert AggregationError("Keccak root mismatch");

        // Check that the job's previous MMR size is the same as the one stored in the contract state
        if (mmrPreviousSize != aggregatorState.mmrSize)
            revert AggregationError("MMR size mismatch");

        if (rightBoundStartParentHash == bytes32(0)) {
            // If the right bound start parent hash __is not__ specified,
            // we check that the job's `blockN + 1 parent hash` is matching with the previously stored parent hash
            if (
                output.blockNPlusOneParentHash !=
                aggregatorState.continuableParentHash
            ) {
                revert AggregationError("Global state: Parent hash mismatch");
            }
        } else {
            // If the right bound start parent hash __is__ specified,
            // we check that the job's `blockN + 1 parent hash` is matching with a previously stored parent hash
            if (output.blockNPlusOneParentHash != rightBoundStartParentHash) {
                revert AggregationError("Parent hash mismatch");
            }
        }
    }

    /// @notice Ensures the job outputs are correctly linked
    /// @param output The job output to check
    /// @param nextOutput The next job output to check
    function ensureConsecutiveJobs(
        JobOutputPacked memory output,
        JobOutputPacked memory nextOutput
    ) internal pure {
        (, uint256 toBlock) = output.blockNumbersPacked.split128();

        // We cannot aggregate further past the genesis block
        if (toBlock == 0) {
            revert GenesisBlockReached();
        }

        (uint256 nextFromBlock, ) = nextOutput.blockNumbersPacked.split128();

        // We check that the next job's `from block` is the same as the previous job's `to block + 1`
        if (toBlock - 1 != nextFromBlock) revert AggregationBlockMismatch();

        (, uint256 outputMmrNewSize) = output.mmrSizesPacked.split128();
        (uint256 nextOutputMmrPreviousSize, ) = nextOutput
            .mmrSizesPacked
            .split128();

        // We check that the previous job's new Poseidon MMR root matches the next job's previous Poseidon MMR root
        if (output.mmrNewRootPoseidon != nextOutput.mmrPreviousRootPoseidon)
            revert AggregationError("Poseidon root mismatch");

        // We check that the previous job's new Keccak MMR root matches the next job's previous Keccak MMR root
        if (output.mmrNewRootKeccak != nextOutput.mmrPreviousRootKeccak)
            revert AggregationError("Keccak root mismatch");

        // We check that the previous job's new MMR size matches the next job's previous MMR size
        if (outputMmrNewSize != nextOutputMmrPreviousSize)
            revert AggregationError("MMR size mismatch");

        // We check that the previous job's lowest block hash matches the next job's highest block hash
        if (
            output.blockNMinusRPlusOneParentHash !=
            nextOutput.blockNPlusOneParentHash
        ) revert AggregationError("Parent hash mismatch");
    }

    /// @dev Helper function to verify a fact based on a job output
    function verifyFact(uint256[] memory outputs) external view returns (bool) {
        bytes32 outputHash = keccak256(abi.encodePacked(outputs));
        bytes32 fact = keccak256(abi.encode(PROGRAM_HASH, outputHash));

        return FACTS_REGISTRY.isValid(fact);
    }

    /// @notice Returns the current root hash of the Keccak Merkle Mountain Range (MMR) tree
    function getMMRKeccakRoot() external view returns (bytes32) {
        return aggregatorState.keccakMmrRoot;
    }

    /// @notice Returns the current root hash of the Poseidon Merkle Mountain Range (MMR) tree
    function getMMRPoseidonRoot() external view returns (bytes32) {
        return aggregatorState.poseidonMmrRoot;
    }

    /// @notice Returns the current size of the Merkle Mountain Range (MMR) trees
    function getMMRSize() external view returns (uint256) {
        return aggregatorState.mmrSize;
    }
}
