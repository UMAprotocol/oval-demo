// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {CommonTest} from "./Common.sol";
import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {ChainlinkOvalImmutable, IAggregatorV3Source} from "oval-quickstart/ChainlinkOvalImmutable.sol";

import {MockV3Aggregator} from "../src/mock/MockV3Aggregator.sol";

contract HoneyPotTest is CommonTest {
    event ReceivedEther(address sender, uint256 amount);
    event DrainedEther(address to, uint256 amount);
    event OracleUpdated(address indexed newOracle);
    event HoneyPotCreated(address indexed owner, int256 initialPrice, uint256 initialBalance);
    event HoneyPotEmptied(address indexed owner, address indexed liquidator, uint256 amount);
    event HoneyPotReset(address indexed owner, uint256 amount);

    IAggregatorV3Source chainlink = IAggregatorV3Source(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    ChainlinkOvalImmutable oracle;
    HoneyPot honeyPot;
    HoneyPotDAO honeyPotDAO;

    uint256 public constant liquidationPrice = 0.1e18;
    uint256 public honeyPotBalance = 1 ether;

    function setUp() public {
        vm.createSelectFork("mainnet", 18419040); // Recent block on mainnet
        address[] memory unlockers = new address[](1);
        unlockers[0] = address(this);
        uint8 decimals = chainlink.decimals();
        oracle = new ChainlinkOvalImmutable(chainlink, decimals, 3, 10, unlockers);

        honeyPot = new HoneyPot(IAggregatorV3Source(address(oracle)));
        honeyPotDAO = new HoneyPotDAO();
    }

    receive() external payable {}

    function mockChainlinkPriceChange() public {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlink.latestRoundData();
        vm.mockCall(
            address(chainlink),
            abi.encodeWithSelector(chainlink.latestRoundData.selector),
            abi.encode(
                roundId + 1,
                (answer * 103) / 100, // 3% increase
                startedAt + 1,
                updatedAt + 1,
                answeredInRound + 1
            )
        );
    }

    function testHoneyPotCreationAndReset() public {
        uint256 balanceBefore = address(this).balance;

        // Create HoneyPot for the caller
        honeyPot.createHoneyPot{value: honeyPotBalance}();

        (, uint256 testhoneyPotBalance) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalance == honeyPotBalance);
        assertTrue(address(this).balance == balanceBefore - honeyPotBalance);

        // Reset HoneyPot for the caller
        vm.expectEmit(true, true, true, true);
        emit HoneyPotReset(address(this), honeyPotBalance);
        honeyPot.resetPot();
        (, uint256 testhoneyPotBalanceReset) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalanceReset == 0);
        assertTrue(address(this).balance == balanceBefore);
    }

    function testCrackHoneyPot() public {
        // Create HoneyPot for the caller
        (, int256 currentPrice,,,) = oracle.latestRoundData();
        vm.expectEmit(true, true, true, true);
        emit HoneyPotCreated(address(this), currentPrice, honeyPotBalance);
        honeyPot.createHoneyPot{value: honeyPotBalance}();
        (, uint256 testhoneyPotBalance) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalance == honeyPotBalance);

        vm.prank(liquidator);
        vm.expectRevert("Liquidation price reached for this user");
        honeyPot.emptyHoneyPot(address(this));

        // Simulate price change
        mockChainlinkPriceChange();

        // Unlock the latest value
        oracle.unlockLatestValue();

        uint256 liquidatorBalanceBefore = liquidator.balance;

        vm.prank(liquidator);
        vm.expectEmit(true, true, true, true);
        emit HoneyPotEmptied(address(this), liquidator, honeyPotBalance);
        honeyPot.emptyHoneyPot(address(this));

        uint256 liquidatorBalanceAfter = liquidator.balance;

        assertTrue(liquidatorBalanceAfter == liquidatorBalanceBefore + honeyPotBalance);

        // Create HoneyPot can be called again
        honeyPot.createHoneyPot{value: honeyPotBalance}();
        (, uint256 testhoneyPotBalanceTwo) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalanceTwo == honeyPotBalance);
    }

    function testCrackHoneyPotWithMockOracle() public {
        // Setup mock oracle
        MockV3Aggregator mock = new MockV3Aggregator(8, 100000000000);
        address[] memory unlockers = new address[](1);
        unlockers[0] = address(this);
        oracle = new ChainlinkOvalImmutable(IAggregatorV3Source(address(mock)), 8, 3, 10, unlockers);
        honeyPot = new HoneyPot(IAggregatorV3Source(address(oracle)));

        // Create HoneyPot for the caller
        (, int256 currentPrice,,,) = oracle.latestRoundData();
        vm.expectEmit(true, true, true, true);
        emit HoneyPotCreated(address(this), currentPrice, honeyPotBalance);
        honeyPot.createHoneyPot{value: honeyPotBalance}();
        (, uint256 testhoneyPotBalance) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalance == honeyPotBalance);

        // Simulate price change
        int256 newAnswer = (currentPrice * 103) / 100;
        bytes32[] memory empty = new bytes32[](0);
        mock.transmit(abi.encode(newAnswer), empty, empty, bytes32(0));

        // Unlock the latest value
        oracle.unlockLatestValue();

        uint256 liquidatorBalanceBefore = liquidator.balance;

        vm.prank(liquidator);
        vm.expectEmit(true, true, true, true);
        emit HoneyPotEmptied(address(this), liquidator, honeyPotBalance);
        honeyPot.emptyHoneyPot(address(this));

        uint256 liquidatorBalanceAfter = liquidator.balance;

        assertTrue(liquidatorBalanceAfter == liquidatorBalanceBefore + honeyPotBalance);
    }

    function testHoneyPotDAO() public {
        vm.expectEmit(true, true, true, true);
        emit ReceivedEther(address(this), 1 ether);
        payable(address(honeyPotDAO)).transfer(1 ether);

        vm.expectEmit(true, true, true, true);
        emit DrainedEther(address(this), 1 ether);
        honeyPotDAO.drain();
    }

    function testCreateHoneyPotWithNoValue() public {
        vm.expectRevert("No value sent");
        honeyPot.createHoneyPot{value: 0}();
    }

    function testEmptyHoneyPotWithZeroBalance() public {
        // Assuming honeyPot has been created before
        // Reset HoneyPot for the caller to ensure balance is 0
        honeyPot.resetPot();

        vm.prank(liquidator);
        vm.expectRevert("No balance to withdraw");
        honeyPot.emptyHoneyPot(address(this));
    }

    function testSetOracle() public {
        vm.expectEmit(true, true, true, true);
        emit OracleUpdated(random);
        honeyPot.setOracle(IAggregatorV3Source(random));
    }
}
