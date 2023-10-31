// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/SharpFactsAggregator.sol";
import "../src/lib/Uint256Splitter.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";

contract SharpFactsAggregatorTest is Test {
    using Uint256Splitter for uint256;

    uint256 latestBlockNumber;

    SharpFactsAggregator public sharpFactsAggregator;

    event Aggregate(
        uint256 fromBlockNumberHigh,
        uint256 toBlockNumberLow,
        bytes32 poseidonMmrRoot,
        bytes32 keccakMmrRoot,
        uint256 mmrSize,
        bytes32 continuableParentHash
    );

    // poseidon_hash(1, "brave new world")
    bytes32 public constant POSEIDON_MMR_INITIAL_ROOT =
        0x06759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

    // keccak_hash(1, "brave new world")
    bytes32 public constant KECCAK_MMR_INITIAL_ROOT =
        0x5d8d23518dd388daa16925ff9475c5d1c06430d21e0422520d6a56402f42937b;

    function setUp() public {
        // The config hereunder must be specified in `foundry.toml`:
        // [rpc_endpoints]
        // goerli="GOERLI_RPC_URL"
        vm.createSelectFork(vm.rpcUrl("goerli"));

        latestBlockNumber = block.number;

        SharpFactsAggregator.AggregatorState
            memory initialAggregatorState = SharpFactsAggregator
                .AggregatorState({
                    poseidonMmrRoot: POSEIDON_MMR_INITIAL_ROOT,
                    keccakMmrRoot: KECCAK_MMR_INITIAL_ROOT,
                    mmrSize: 1,
                    continuableParentHash: bytes32(0)
                });

        sharpFactsAggregator = new SharpFactsAggregator(
            IFactsRegistry(0xAB43bA48c9edF4C2C4bB01237348D1D7B28ef168) // Goërli
        );

        // Ensure roles were not granted
        assertFalse(
            sharpFactsAggregator.hasRole(
                keccak256("OPERATOR_ROLE"),
                address(this)
            )
        );
        assertFalse(
            sharpFactsAggregator.hasRole(
                keccak256("UNLOCKER_ROLE"),
                address(this)
            )
        );

        sharpFactsAggregator.initialize(
            // Initial aggregator state (empty trees)
            initialAggregatorState
        );

        // Ensure roles were successfuly granted
        assertTrue(
            sharpFactsAggregator.hasRole(
                keccak256("OPERATOR_ROLE"),
                address(this)
            )
        );
        assertTrue(
            sharpFactsAggregator.hasRole(
                keccak256("UNLOCKER_ROLE"),
                address(this)
            )
        );
    }

    function testVerifyInvalidFact() public {
        // Fake output
        uint256[] memory outputs = new uint256[](1);
        outputs[0] = 4242424242;

        assertFalse(sharpFactsAggregator.verifyFact(outputs));
    }

    function ensureGlobalStateCorrectness(
        SharpFactsAggregator.JobOutputPacked memory output
    ) internal view {
        (
            bytes32 poseidonMmrRoot,
            bytes32 keccakMmrRoot,
            uint256 mmrSize,
            bytes32 continuableParentHash
        ) = sharpFactsAggregator.aggregatorState();

        (, uint256 mmrNewSize) = output.mmrSizesPacked.split128();

        assert(poseidonMmrRoot == output.mmrNewRootPoseidon);
        assert(keccakMmrRoot == output.mmrNewRootKeccak);
        assert(mmrSize == mmrNewSize);
        assert(continuableParentHash == output.blockNMinusRPlusOneParentHash);
    }

    function testRealAggregateJobsFFI() public {
        vm.makePersistent(address(sharpFactsAggregator));

        vm.createSelectFork(vm.rpcUrl("mainnet"));

        uint256 firstRangeStartChildBlock = 20;
        uint256 secondRangeStartChildBlock = 30;

        uint256 pastBlockStart = firstRangeStartChildBlock + 50;
        // Start at block no. 70
        vm.rollFork(pastBlockStart);

        sharpFactsAggregator.registerNewRange(
            pastBlockStart - firstRangeStartChildBlock - 1
        );

        sharpFactsAggregator.registerNewRange(
            pastBlockStart - secondRangeStartChildBlock - 1
        );

        (
            bytes32 poseidonMmrRoot,
            bytes32 keccakMmrRoot,
            uint256 mmrSize,
            bytes32 continuableParentHash
        ) = sharpFactsAggregator.aggregatorState(); // Get initialized tree state

        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "./helpers/compute-outputs.js";
        inputs[2] = "helpers/outputs_batch_mainnet.json";
        bytes memory output = vm.ffi(inputs);

        SharpFactsAggregator.JobOutputPacked[] memory outputs = abi.decode(
            output,
            (SharpFactsAggregator.JobOutputPacked[])
        );

        SharpFactsAggregator.JobOutputPacked memory firstOutput = outputs[0];
        assert(mmrSize == 1); // New tree, with genesis element "brave new world" only
        console.logBytes32(continuableParentHash);
        assert(continuableParentHash == firstOutput.blockNPlusOneParentHash);
        assert(poseidonMmrRoot == firstOutput.mmrPreviousRootPoseidon);
        assert(keccakMmrRoot == firstOutput.mmrPreviousRootKeccak);

        vm.createSelectFork(vm.rpcUrl("goerli"));

        vm.rollFork(latestBlockNumber);

        sharpFactsAggregator.aggregateSharpJobs(0, outputs);
        ensureGlobalStateCorrectness(outputs[outputs.length - 1]);

        string[] memory inputsExtended = new string[](3);
        inputsExtended[0] = "node";
        inputsExtended[1] = "./helpers/compute-outputs.js";
        inputsExtended[2] = "helpers/outputs_batch_mainnet_extended.json";
        bytes memory outputExtended = vm.ffi(inputsExtended);

        SharpFactsAggregator.JobOutputPacked[] memory outputsExtended = abi
            .decode(outputExtended, (SharpFactsAggregator.JobOutputPacked[]));

        sharpFactsAggregator.aggregateSharpJobs(
            secondRangeStartChildBlock + 1,
            outputsExtended
        );
        ensureGlobalStateCorrectness(
            outputsExtended[outputsExtended.length - 1]
        );
    }
}
