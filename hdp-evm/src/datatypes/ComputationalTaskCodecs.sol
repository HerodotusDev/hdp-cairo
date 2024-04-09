// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev A ComputationalTask.
/// @param AggregateFnId The aggregate function id.
/// @param operator The operator to use (only COUNT).
/// @param valueToCompare The value to compare (only COUNT).
/// The context is used to pass additional parameters to the aggregate function.
struct ComputationalTask {
    AggregateFn aggregateFnId;
    Operator operatorId;
    uint256 valueToCompare;
}

///@notice Aggregates functions.
enum AggregateFn {
    AVG,
    SUM,
    MIN,
    MAX,
    COUNT,
    MERKLE
}

///@notice Operators for COUNT.
enum Operator {
    NONE,
    EQ,
    NEQ,
    GT,
    GTE,
    LT,
    LTE
}

/// @notice Codecs for ComputationalTask.
/// @dev Represent a computational task with an aggregate function and context.
library ComputationalTaskCodecs {
    /// @dev Encodes a ComputationalTask.
    /// @param task The ComputationalTask to encode.
    function encode(ComputationalTask memory task) internal pure returns (bytes memory) {
        return abi.encode(task.aggregateFnId, task.operatorId, task.valueToCompare);
    }

    /// @dev Get the commitment of a ComputationalTask.
    /// @notice The commitment embeds the datalake commitment.
    /// @param task The ComputationalTask to commit.
    /// @param datalakeCommitment The commitment of the datalake.
    function commit(ComputationalTask memory task, bytes32 datalakeCommitment) internal pure returns (bytes32) {
        return keccak256(abi.encode(datalakeCommitment, task.aggregateFnId, task.operatorId, task.valueToCompare));
    }

    /// @dev Decodes a ComputationalTask.
    /// @param data The encoded ComputationalTask.
    function decode(bytes memory data) internal pure returns (ComputationalTask memory) {
        (uint8 aggregateFnId, uint8 operator, uint256 valueToCompare) = abi.decode(data, (uint8, uint8, uint256));
        return ComputationalTask({
            aggregateFnId: AggregateFn(aggregateFnId),
            operatorId: Operator(operator),
            valueToCompare: valueToCompare
        });
    }
}
