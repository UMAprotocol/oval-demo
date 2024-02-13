// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {ChainlinkOvalImmutable, IAggregatorV3Source} from "oval-quickstart/ChainlinkOvalImmutable.sol";

import {MockV3Aggregator} from "../src/mock/MockV3Aggregator.sol";

contract HoneyPotDeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address chainlink = vm.envOr("SOURCE_ADDRESS", address(0));
        uint256 lockWindow = vm.envUint("LOCK_WINDOW");
        uint256 maxTraversal = vm.envUint("MAX_TRAVERSAL");
        address unlocker = vm.envAddress("UNLOCKER");
        address[] memory unlockers = new address[](1);
        unlockers[0] = unlocker;

        console.log("Deploying HoneyPot with the following parameters:");
        console.log("  - Chainlink source address: ", chainlink);
        console.log("  - Lock window: ", lockWindow);
        console.log("  - Max traversal: ", maxTraversal);
        console.log("  - Unlocker: ", unlockers[0]);

        vm.startBroadcast(deployerPrivateKey);

        if(chainlink == address(0)) {
            console.log("Chainlink source address is not set");
            console.log("Deploying a mock Chainlink source");
            MockV3Aggregator mock = new MockV3Aggregator(8, 100000000000);
            chainlink = address(mock);
            console.log("Deployed mock Chainlink source at address: ", chainlink);
        }

        IAggregatorV3Source source = IAggregatorV3Source(chainlink);
        uint8 decimals = IAggregatorV3Source(chainlink).decimals();

        ChainlinkOvalImmutable oracle =
            new ChainlinkOvalImmutable(source, decimals, lockWindow, maxTraversal, unlockers);

        console.log("Deployed ChainlinkOvalImmutable contract at address: ", address(oracle));

        HoneyPot honeyPot = new HoneyPot(IAggregatorV3Source(address(oracle)));

        console.log("Deployed HoneyPot contract at address: ", address(honeyPot));

        HoneyPotDAO honeyPotDAO = new HoneyPotDAO();

        console.log("Deployed HoneyPotDAO contract at address: ", address(honeyPotDAO));

        vm.stopBroadcast();
    }
}
