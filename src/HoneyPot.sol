// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HoneyPotOEVShare} from "./HoneyPotOEVShare.sol";

contract HoneyPot is Ownable {
    struct HoneyPotDetails {
        uint256 liquidationPrice;
        uint256 balance;
    }

    mapping(address => HoneyPotDetails) public honeyPots;
    HoneyPotOEVShare public oracle;

    // Declare events
    event OracleUpdated(address indexed newOracle);
    event HoneyPotCreated(
        address indexed creator,
        uint256 liquidationPrice,
        uint256 initialBalance
    );
    event HoneyPotEmptied(
        address indexed honeyPotCreator,
        address indexed trigger,
        uint256 amount
    );
    event PotReset(address indexed owner, uint256 amount);

    constructor(HoneyPotOEVShare _oracle) {
        oracle = _oracle;
    }

    function setOracle(HoneyPotOEVShare _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleUpdated(address(_oracle)); // Emit event
    }

    function createHoneyPot(uint _liquidationPrice) external payable {
        require(
            honeyPots[msg.sender].liquidationPrice == 0,
            "Liquidation price already set for this user"
        );
        require(_liquidationPrice > 0, "Liquidation price cannot be zero");

        honeyPots[msg.sender].liquidationPrice = _liquidationPrice;
        honeyPots[msg.sender].balance = msg.value; // add the sent ether to the user's honey pot balance

        emit HoneyPotCreated(msg.sender, _liquidationPrice, msg.value); // Emit event
    }

    function emptyHoneyPot(address honeyPotCreator) external {
        int256 currentPrice = oracle.latestAnswer();
        require(currentPrice >= 0, "Invalid price from oracle");

        HoneyPotDetails storage userPot = honeyPots[honeyPotCreator];

        require(
            uint256(currentPrice) != userPot.liquidationPrice,
            "Liquidation price reached for this user"
        );

        uint256 amount = userPot.balance;
        userPot.balance = 0; // reset the balance
        userPot.liquidationPrice = 0; // reset the liquidation price. There was a mistake in the original, missing the assignment.
        payable(msg.sender).transfer(amount);

        emit HoneyPotEmptied(honeyPotCreator, msg.sender, amount); // Emit event
    }

    function resetPot() external onlyOwner {
        HoneyPotDetails storage userPot = honeyPots[msg.sender];

        userPot.liquidationPrice = 0;
        uint256 amount = userPot.balance;
        userPot.balance = 0; // reset the balance
        payable(msg.sender).transfer(amount);

        emit PotReset(msg.sender, amount); // Emit event
    }
}
