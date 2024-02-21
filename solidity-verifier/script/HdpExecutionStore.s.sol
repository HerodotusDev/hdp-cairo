// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IAggregatorsFactory} from "../src/interfaces/IAggregatorsFactory.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";
import {HdpExecutionStore} from "../src/hdp/HdpExecutionStore.sol";

contract HdpExecutionStoreDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFactsRegistry factsRegistry = IFactsRegistry(
            vm.envAddress("FACTS_REGISTRY_ADDRESS")
        );
        IAggregatorsFactory aggregatorsFactory = IAggregatorsFactory(
            vm.envAddress("AGGREGATORS_FACTORY_ADDRESS")
        );

        // Deploy the HdpExecutionStore
        HdpExecutionStore hdpExecutionStore = new HdpExecutionStore(
            factsRegistry,
            aggregatorsFactory
        );

        console.log(
            "HdpExecutionStore deployed at: ",
            address(hdpExecutionStore)
        );

        vm.stopBroadcast();
    }
}
