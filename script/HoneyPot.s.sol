// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {ChainlinkOvalImmutable, IAggregatorV3Source} from "oval-quickstart/ChainlinkOvalImmutable.sol";

contract HoneyPotDeploymentScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address chainlink = vm.envAddress("SOURCE_ADDRESS");
        uint256 lockWindow = vm.envUint("LOCK_WINDOW");
        uint256 maxTraversal = vm.envUint("MAX_TRAVERSAL");

        // This script assumes exactly one unlocker is set. If you want to set more than one, you'll need to modify this
        // script to have an array of known unlocker addresses.
        string memory unlockersString = vm.envString("UNLOCKERS");
        address[] memory unlockers = new address[](1);
        unlockers[0] = address(uint160(uint256(keccak256(abi.encodePacked(unlockersString)))));

        IAggregatorV3Source source = IAggregatorV3Source(chainlink);
        uint8 decimals = IAggregatorV3Source(chainlink).decimals();
        vm.startBroadcast(deployerPrivateKey);

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
