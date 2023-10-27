// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/console2.sol";
import "forge-std/Script.sol";

import {ChronicleMedianSourceMock} from "../src/mock/ChronicleMedianSourceMock.sol";
import {IMedian} from "oev-contracts/interfaces/chronicle/IMedian.sol";
import {HoneyPotOEVShare} from "../src/HoneyPotOEVShare.sol";
import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";

contract HoneyPotDeploymentScript is Script {
    HoneyPotOEVShare oevShare;
    HoneyPot honeyPot;
    HoneyPotDAO honeyPotDAO;
    ChronicleMedianSourceMock chronicleMock;

    function run() external {
        vm.startBroadcast();

        address chainlink = vm.envOr(
            "CHAINLINK_SOURCE",
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        address pyth = vm.envOr(
            "PYTH_SOURCE",
            0x4305FB66699C3B2702D4d05CF36551390A4c69C6
        );

        bytes32 defaultId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
        bytes32 pythPriceId = vm.envOr("PYTH_PRICE_ID", bytes32(0));
        if (pythPriceId == bytes32(0)) {
            pythPriceId = defaultId;
        }

        // Create mock ChronicleMedianSource and set the latest source data.
        chronicleMock = new ChronicleMedianSourceMock();

        oevShare = new HoneyPotOEVShare(
            chainlink,
            address(chronicleMock),
            pyth,
            pythPriceId,
            8
        );

        honeyPot = new HoneyPot(IAggregatorV3Source(address(oevShare)));

        honeyPotDAO = new HoneyPotDAO();

        vm.stopBroadcast();
    }
}
