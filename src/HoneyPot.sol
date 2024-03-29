// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAggregatorV3Source} from "oval-quickstart/ChainlinkOvalImmutable.sol";

contract HoneyPot is Ownable {
    struct HoneyPotDetails {
        int256 liquidationPrice;
        uint256 balance;
    }

    mapping(address => HoneyPotDetails) public honeyPots;
    IAggregatorV3Source public oracle; // Oval serving as a Chainlink oracle

    event OracleUpdated(address indexed newOracle);
    event HoneyPotCreated(address indexed owner, int256 initialPrice, uint256 amount);
    event HoneyPotEmptied(address indexed owner, address indexed liquidator, uint256 amount);
    event HoneyPotReset(address indexed owner, uint256 amount);

    constructor(IAggregatorV3Source _oracle) {
        oracle = _oracle;
    }

    function setOracle(IAggregatorV3Source _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleUpdated(address(_oracle));
    }

    function createHoneyPot() external payable {
        require(honeyPots[msg.sender].liquidationPrice == 0, "Liquidation price already set for this user");
        require(msg.value > 0, "No value sent");

        (, int256 currentPrice,,,) = oracle.latestRoundData();

        honeyPots[msg.sender].liquidationPrice = currentPrice;
        honeyPots[msg.sender].balance = msg.value;

        emit HoneyPotCreated(msg.sender, currentPrice, msg.value);
    }

    function _emptyPotForUser(address owner, address recipient) internal returns (uint256 amount) {
        HoneyPotDetails storage userPot = honeyPots[owner];

        amount = userPot.balance;
        userPot.balance = 0; // reset the balance
        userPot.liquidationPrice = 0; // reset the liquidation price
        Address.sendValue(payable(recipient), amount);
    }

    function emptyHoneyPot(address owner) external {
        (, int256 currentPrice,,,) = oracle.latestRoundData();
        require(currentPrice >= 0, "Invalid price from oracle");

        HoneyPotDetails storage userPot = honeyPots[owner];

        require(currentPrice != userPot.liquidationPrice, "Liquidation price reached for this user");
        require(userPot.balance > 0, "No balance to withdraw");

        uint256 withdrawnAmount = _emptyPotForUser(owner, msg.sender);
        emit HoneyPotEmptied(owner, msg.sender, withdrawnAmount);
    }

    function resetPot() external {
        uint256 withdrawnAmount = _emptyPotForUser(msg.sender, msg.sender);
        emit HoneyPotReset(msg.sender, withdrawnAmount);
    }
}
