// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HoneyPotOEVShare} from "./HoneyPotOEVShare.sol";

contract HoneyPot is Ownable {
    uint256 public liquidationPrice;
    HoneyPotOEVShare public oracle;

    constructor(HoneyPotOEVShare _oracle) {
        oracle = _oracle;
    }

    function setOracle(HoneyPotOEVShare _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function createHoneyPot(uint _liquidationPrice) external payable {
        require(liquidationPrice == 0, "Liquidation price already set");
        liquidationPrice = _liquidationPrice;
    }

    function emptyHoneyPot() external {
        int256 currentPrice = oracle.latestAnswer();
        require(currentPrice >= 0, "Invalid price from oracle");
        require(
            uint256(currentPrice) != liquidationPrice,
            "Liquidation price reached"
        );
        payable(msg.sender).transfer(address(this).balance);
    }

    function resetPot() external onlyOwner {
        liquidationPrice = 0;
        payable(msg.sender).transfer(address(this).balance);
    }
}
