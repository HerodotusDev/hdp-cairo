// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @dev A ComputationalTask.
/// @param aggregateFnId The aggregate function id.
/// @param aggregateFnCtx The aggregate function context.
/// The context is used to pass additional parameters to the aggregate function.
struct ComputationalTask {
    uint256 aggregateFnId;
    bytes aggregateFnCtx;
}

/// @notice Codecs for ComputationalTask.
/// @dev Represent a computational task with an aggregate function and context.
library ComputationalTaskCodecs {
    /// @dev Encodes a ComputationalTask.
    /// @param task The ComputationalTask to encode.
    function encode(
        ComputationalTask memory task
    ) internal pure returns (bytes memory) {
        return abi.encode(task.aggregateFnId, task.aggregateFnCtx);
    }

    /// @dev Get the commitment of a ComputationalTask.
    /// @notice The commitment embeds the datalake commitment.
    /// @param task The ComputationalTask to commit.
    /// @param datalakeCommitment The commitment of the datalake.
    function commit(
        ComputationalTask memory task,
        bytes32 datalakeCommitment
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    datalakeCommitment,
                    task.aggregateFnId,
                    task.aggregateFnCtx
                )
            );
    }

    /// @dev Decodes a ComputationalTask.
    /// @param data The encoded ComputationalTask.
    function decode(
        bytes memory data
    ) internal pure returns (ComputationalTask memory) {
        (uint256 aggregateFnId, bytes memory aggregateFnCtx) = abi.decode(
            data,
            (uint256, bytes)
        );
        return
            ComputationalTask({
                aggregateFnId: aggregateFnId,
                aggregateFnCtx: aggregateFnCtx
            });
    }
}
