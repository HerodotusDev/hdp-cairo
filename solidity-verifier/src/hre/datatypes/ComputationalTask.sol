// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ComputationalTask {
    uint256 aggregateFnId;
    bytes aggregateFnCtx;
}

library ComputationalTaskCodecs {
    function encode(
        ComputationalTask memory task
    ) internal pure returns (bytes memory) {
        return abi.encode(task.aggregateFnId, task.aggregateFnCtx);
    }

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
