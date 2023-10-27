// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {HoneyPotOEVShare} from "../src/HoneyPotOEVShare.sol";
import {HoneyPot} from "../src/HoneyPot.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";

contract HoneyPotDeploymentScript is Script {
    HoneyPotOEVShare oevShare;
    HoneyPot honeyPot;

    function run() external {
        // Get deployment parameters from environment variables or use defaults.

        vm.startBroadcast();

        address chainlink = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        address chronicle = 0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85;
        address pyth = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
        bytes32 pythPriceId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

        oevShare = new HoneyPotOEVShare(
            chainlink,
            chronicle,
            pyth,
            pythPriceId,
            8
        );

        honeyPot = new HoneyPot(IAggregatorV3Source(address(oevShare)));

        vm.stopBroadcast();
    }
}
