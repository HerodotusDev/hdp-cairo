// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

import {IAggregatorsFactory} from "../src/interfaces/IAggregatorsFactory.sol";
import {IFactsRegistry} from "../src/interfaces/IFactsRegistry.sol";
import {HdpExecutionStore} from "../src/HdpExecutionStore.sol";

contract HdpExecutionStoreDeployer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        IFactsRegistry factsRegistry = IFactsRegistry(vm.envAddress("FACTS_REGISTRY_ADDRESS"));
        IAggregatorsFactory aggregatorsFactory = IAggregatorsFactory(vm.envAddress("AGGREGATORS_FACTORY_ADDRESS"));

        // Deploy the HdpExecutionStore
        HdpExecutionStore hdpExecutionStore = new HdpExecutionStore(factsRegistry, aggregatorsFactory);

        console2.log("HdpExecutionStore deployed at: ", address(hdpExecutionStore));

        vm.stopBroadcast();
    }
}
