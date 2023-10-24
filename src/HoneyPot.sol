// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";

contract HoneyPot is Ownable {
    struct HoneyPotDetails {
        int256 liquidationPrice;
        uint256 balance;
    }

    mapping(address => HoneyPotDetails) public honeyPots;
    IAggregatorV3Source public oracle; // OEV Share serving as a Chainlink oracle

    event OracleUpdated(address indexed newOracle);
    event HoneyPotCreated(
        address indexed creator,
        int256 liquidationPrice,
        uint256 initialBalance
    );
    event HoneyPotEmptied(
        address indexed honeyPotCreator,
        address indexed trigger,
        uint256 amount
    );
    event PotReset(address indexed owner, uint256 amount);

    constructor(IAggregatorV3Source _oracle) {
        oracle = _oracle;
    }

    function setOracle(IAggregatorV3Source _oracle) external onlyOwner {
        oracle = _oracle;
        emit OracleUpdated(address(_oracle));
    }

    function createHoneyPot(int256 _liquidationPrice) external payable {
        require(
            honeyPots[msg.sender].liquidationPrice == 0,
            "Liquidation price already set for this user"
        );
        require(_liquidationPrice > 0, "Liquidation price cannot be zero");

        honeyPots[msg.sender].liquidationPrice = _liquidationPrice;
        honeyPots[msg.sender].balance = msg.value;

        emit HoneyPotCreated(msg.sender, _liquidationPrice, msg.value);
    }

    function emptyHoneyPot(address honeyPotCreator) external {
        (, int256 currentPrice, , , ) = oracle.latestRoundData();
        require(currentPrice >= 0, "Invalid price from oracle");

        HoneyPotDetails storage userPot = honeyPots[honeyPotCreator];

        require(
            currentPrice != userPot.liquidationPrice,
            "Liquidation price reached for this user"
        );

        uint256 amount = userPot.balance;
        userPot.balance = 0; // reset the balance
        userPot.liquidationPrice = 0; // reset the liquidation price
        Address.sendValue(payable(msg.sender), amount);

        emit HoneyPotEmptied(honeyPotCreator, msg.sender, amount);
    }

    function resetPot() external {
        HoneyPotDetails storage userPot = honeyPots[msg.sender];

        userPot.liquidationPrice = 0; // reset the liquidation price
        uint256 amount = userPot.balance;
        userPot.balance = 0; // reset the balance
        Address.sendValue(payable(msg.sender), amount);

        emit PotReset(msg.sender, amount);
    }
}
