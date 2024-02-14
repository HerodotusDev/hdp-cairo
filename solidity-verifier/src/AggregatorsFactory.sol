// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import {SharpFactsAggregator} from "../src/SharpFactsAggregator.sol";

/// @title AggregatorsFactory
/// @author Herodotus Dev
/// @notice A factory contract for creating new SharpFactsAggregator contracts
///         and upgrading new one's starter template
contract AggregatorsFactory is AccessControl {
    // Blank contract template address
    SharpFactsAggregator public template;

    // Timelock mechanism for upgrades proposals
    struct UpgradeProposalTimelock {
        uint256 timestamp;
        SharpFactsAggregator newTemplate;
    }

    // Upgrades timelocks
    mapping(uint256 => UpgradeProposalTimelock) public upgrades;

    // Upgrades tracker
    uint256 public upgradesCount;

    // Delay before an upgrade can be performed
    uint256 public constant DELAY = 3 days;

    // Aggregators indexing
    uint256 public aggregatorsCount;

    // Aggregators by id
    mapping(uint256 => SharpFactsAggregator) public aggregatorsById;

    // Access control
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Default roots for new aggregators:
    // poseidon_hash(1, "brave new world")
    bytes32 public constant POSEIDON_MMR_INITIAL_ROOT =
        0x06759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

    // keccak_hash(1, "brave new world")
    bytes32 public constant KECCAK_MMR_INITIAL_ROOT = 0x5d8d23518dd388daa16925ff9475c5d1c06430d21e0422520d6a56402f42937b;

    // Events
    event UpgradeProposal(SharpFactsAggregator newTemplate);
    event Upgrade(SharpFactsAggregator oldTemplate, SharpFactsAggregator newTemplate);
    event AggregatorCreation(
        SharpFactsAggregator aggregator, uint256 newAggregatorId, uint256 detachedFromAggregatorId
    );

    /// Creates a new Factory contract and grants OPERATOR_ROLE to the deployer
    /// @param initialTemplate The address of the template contract to clone
    constructor(SharpFactsAggregator initialTemplate) {
        template = initialTemplate;

        _setRoleAdmin(OPERATOR_ROLE, OPERATOR_ROLE);
        _grantRole(OPERATOR_ROLE, _msgSender());
    }

    /// @notice Reverts if the caller is not an operator
    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, _msgSender()), "Caller is not an operator");
        _;
    }

    /**
     * Creates a new aggregator contract by cloning the template contract
     * @param aggregatorId The id of an existing aggregator to attach to (0 for none)
     */
    function createAggregator(uint256 aggregatorId) external onlyOperator returns (address) {
        SharpFactsAggregator.AggregatorState memory initialAggregatorState;

        if (aggregatorId != 0) {
            // Attach from existing aggregator
            require(aggregatorId <= aggregatorsCount, "Invalid aggregator ID");

            address existingAggregatorAddr = address(aggregatorsById[aggregatorId]);
            require(existingAggregatorAddr != address(0), "Aggregator not found");

            SharpFactsAggregator existingAggregator = SharpFactsAggregator(existingAggregatorAddr);

            (bytes32 poseidonMmrRoot, bytes32 keccakMmrRoot, uint256 mmrSize, bytes32 continuableParentHash) =
                existingAggregator.aggregatorState();
            initialAggregatorState.poseidonMmrRoot = poseidonMmrRoot;
            initialAggregatorState.keccakMmrRoot = keccakMmrRoot;
            initialAggregatorState.mmrSize = mmrSize;
            initialAggregatorState.continuableParentHash = continuableParentHash;
        } else {
            // Create a new aggregator (detach from existing ones)
            initialAggregatorState = SharpFactsAggregator.AggregatorState({
                poseidonMmrRoot: POSEIDON_MMR_INITIAL_ROOT,
                keccakMmrRoot: KECCAK_MMR_INITIAL_ROOT,
                mmrSize: 1,
                continuableParentHash: bytes32(0)
            });
        }

        // Initialize the newly created aggregator
        bytes memory data =
            abi.encodeWithSignature("initialize((bytes32,bytes32,uint256,bytes32))", initialAggregatorState);

        // Clone the template contract
        address clone = Clones.clone(address(template));

        // The data is the encoded initialize function (with initial parameters)
        (bool success,) = clone.call(data);

        require(success, "Aggregator initialization failed");

        aggregatorsById[++aggregatorsCount] = SharpFactsAggregator(clone);

        emit AggregatorCreation(SharpFactsAggregator(clone), aggregatorsCount, aggregatorId);

        // Grant roles to the caller so that roles are not stuck in the Factory
        SharpFactsAggregator(clone).grantRole(keccak256("OPERATOR_ROLE"), _msgSender());
        SharpFactsAggregator(clone).grantRole(keccak256("UNLOCKER_ROLE"), _msgSender());

        return clone;
    }

    /**
     * Proposes an upgrade to the template (blank aggregator) contract
     * @param newTemplate The address of the new template contract to use for future aggregators
     */
    function proposeUpgrade(SharpFactsAggregator newTemplate) external onlyOperator {
        upgrades[++upgradesCount] = UpgradeProposalTimelock(block.timestamp + DELAY, newTemplate);

        emit UpgradeProposal(newTemplate);
    }

    /**
     * Upgrades the template (blank aggregator) contract
     * @param updateId The id of the upgrade proposal to execute
     */
    function upgrade(uint256 updateId) external onlyOperator {
        require(updateId == upgradesCount, "Invalid updateId");

        uint256 timeLockTimestamp = upgrades[updateId].timestamp;
        require(timeLockTimestamp != 0, "TimeLock not set");
        require(block.timestamp >= timeLockTimestamp, "TimeLock not expired");

        address oldTemplate = address(template);
        template = SharpFactsAggregator(upgrades[updateId].newTemplate);

        // Clear timelock
        upgrades[updateId] = UpgradeProposalTimelock(0, SharpFactsAggregator(address(0)));

        emit Upgrade(SharpFactsAggregator(oldTemplate), template);
    }
}
