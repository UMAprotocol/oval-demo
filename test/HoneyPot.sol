// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "forge-std/console.sol";

import {CommonTest} from "./Common.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";
import {IMedian} from "oev-contracts/interfaces/chronicle/IMedian.sol";
import {IPyth} from "oev-contracts/interfaces/pyth/IPyth.sol";

import {HoneyPotOEVShare} from "../src/HoneyPotOEVShare.sol";
import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {ChronicleMedianSourceMock} from "../src/mock/ChronicleMedianSourceMock.sol";
import {PythSourceMock} from "../src/mock/PythSourceMock.sol";

contract HoneyPotTest is CommonTest {
    event ReceivedEther(address sender, uint256 amount);
    event DrainedEther(address to, uint256 amount);
    event OracleUpdated(address indexed newOracle);
    event HoneyPotCreated(address indexed creator, int256 liquidationPrice, uint256 initialBalance);
    event HoneyPotEmptied(address indexed honeyPotCreator, address indexed trigger, uint256 amount);
    event PotReset(address indexed owner, uint256 amount);

    IAggregatorV3Source chainlink = IAggregatorV3Source(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IMedian chronicle = IMedian(0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85);
    IPyth pyth = IPyth(0x4305FB66699C3B2702D4d05CF36551390A4c69C6);
    bytes32 pythPriceId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    ChronicleMedianSourceMock chronicleMock;
    PythSourceMock pythMock;

    HoneyPotOEVShare oevShare;
    HoneyPot honeyPot;
    HoneyPotDAO honeyPotDAO;

    uint256 public constant liquidationPrice = 0.1e18;
    uint256 public honeyPotBalance = 1 ether;

    function setUp() public {
        vm.createSelectFork("mainnet", 18419040); // Recent block on mainnet
        oevShare = new HoneyPotOEVShare(
            address(chainlink),
            address(chronicle),
            address(pyth),
            pythPriceId,
            8
        );

        honeyPot = new HoneyPot(IAggregatorV3Source(address(oevShare)));
        honeyPotDAO = new HoneyPotDAO();
        _whitelistOnChronicle();
        oevShare.setUnlocker(address(this), true);
        chronicleMock = new ChronicleMedianSourceMock();
        pythMock = new PythSourceMock();
    }

    receive() external payable {}

    function _whitelistOnChronicle() internal {
        vm.startPrank(0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB); // DSPause that is a ward (can add kiss to chronicle)
        chronicle.kiss(address(oevShare));
        chronicle.kiss(address(this)); // So that we can read Chronicle directly.
        vm.stopPrank();
    }

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
        emit PotReset(address(this), honeyPotBalance);
        honeyPot.resetPot();
        (, uint256 testhoneyPotBalanceReset) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalanceReset == 0);
        assertTrue(address(this).balance == balanceBefore);
    }

    function testCrackHoneyPot() public {
        // Create HoneyPot for the caller
        (, int256 currentPrice,,,) = oevShare.latestRoundData();
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
        oevShare.unlockLatestValue();

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

    function testHoneyPotDAO() public {
        vm.expectEmit(true, true, true, true);
        emit ReceivedEther(address(this), 1 ether);
        payable(address(honeyPotDAO)).transfer(1 ether);

        vm.expectEmit(true, true, true, true);
        emit DrainedEther(address(this), 1 ether);
        honeyPotDAO.drain();
    }

    function testChronicleMock() public {
        uint32 age = chronicle.age();
        uint256 read = chronicle.read();
        chronicleMock.setLatestSourceData(read, age);

        HoneyPotOEVShare oevShare2 = new HoneyPotOEVShare(
            address(chainlink),
            address(chronicleMock),
            address(pyth),
            pythPriceId,
            8
        );
        oevShare2.setUnlocker(address(this), true);

        HoneyPot honeyPot2 = new HoneyPot(
            IAggregatorV3Source(address(oevShare2))
        );

        // Create HoneyPot for the caller
        honeyPot2.createHoneyPot{value: honeyPotBalance}();
        (, uint256 testhoneyPotBalance) = honeyPot2.honeyPots(address(this));
        assertTrue(testhoneyPotBalance == honeyPotBalance);

        vm.prank(liquidator);
        vm.expectRevert("Liquidation price reached for this user");
        honeyPot2.emptyHoneyPot(address(this));

        // Simulate price change
        chronicleMock.setLatestSourceData((read * 103) / 100, uint32(block.timestamp - 1));

        // Unlock the latest value
        oevShare2.unlockLatestValue();

        uint256 liquidatorBalanceBefore = liquidator.balance;

        vm.prank(liquidator);
        honeyPot2.emptyHoneyPot(address(this));

        uint256 liquidatorBalanceAfter = liquidator.balance;

        assertTrue(liquidatorBalanceAfter == liquidatorBalanceBefore + honeyPotBalance);
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

    function testCannotEmptyLockedPythUpdate() public {
        // Set initial Pyth price 1% above current Chainlink price at current timestamp.
        (, int256 chainlinkPrice,, uint256 chainlinkTime,) = chainlink.latestRoundData();
        int64 pythPrice = int64(chainlinkPrice) * 101 / 100;
        pythMock.setLatestPrice(pythPrice, 0, -8, block.timestamp);

        // Deploy and setup contracts.
        HoneyPotOEVShare oevShare3 =
            new HoneyPotOEVShare(address(chainlink), address(chronicleMock), address(pythMock), pythPriceId, 8);
        oevShare3.setUnlocker(address(this), true);
        HoneyPot honeyPot3 = new HoneyPot(IAggregatorV3Source(address(oevShare3)));

        // Check that the latest Oval price is the same as the latest Chainlink price before the unlock.
        (, int256 ovalPrice,, uint256 ovalTime,) = oevShare3.latestRoundData();
        assertTrue(ovalPrice == chainlinkPrice);
        assertTrue(ovalTime == chainlinkTime);

        // Unlock the latest value so that the latest Pyth price is used when creating the HoneyPot.
        oevShare3.unlockLatestValue();
        (, ovalPrice,, ovalTime,) = oevShare3.latestRoundData();
        assertTrue(ovalPrice == pythPrice);
        assertTrue(ovalTime == block.timestamp);
        console.log("Price at honeyPot creation: %s, @%s", uint256(ovalPrice), ovalTime);

        // Create HoneyPot for the caller.
        honeyPot3.createHoneyPot{value: honeyPotBalance}();
        (int256 liquidationPrice, uint256 testhoneyPotBalance) = honeyPot3.honeyPots(address(this));
        assertTrue(liquidationPrice == pythPrice);
        assertTrue(testhoneyPotBalance == honeyPotBalance);

        // Update Pyth price by additional 1% after 10 minutes.
        skip(600);
        pythPrice = pythPrice * 101 / 100;
        pythMock.setLatestPrice(pythPrice, 0, -8, block.timestamp);

        // It should not be possible to empty the HoneyPot without unlocking the latest value.
        (, ovalPrice,, ovalTime,) = oevShare3.latestRoundData();
        console.log("Price at honeyPot empty: %s, @%s", uint256(ovalPrice), ovalTime);
        vm.prank(liquidator);
        vm.expectRevert("Liquidation price reached for this user");
        honeyPot3.emptyHoneyPot(address(this));
    }
}
