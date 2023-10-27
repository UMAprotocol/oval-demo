// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {CommonTest} from "./Common.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";
import {IMedian} from "oev-contracts/interfaces/chronicle/IMedian.sol";
import {IPyth} from "oev-contracts/interfaces/pyth/IPyth.sol";

import {HoneyPotOEVShare} from "../src/HoneyPotOEVShare.sol";
import {HoneyPot} from "../src/HoneyPot.sol";
import {HoneyPotDAO} from "../src/HoneyPotDAO.sol";
import {ChronicleMedianSourceAdapterMock} from "../src/mock/ChronicleMedianSourceAdapterMock.sol";

contract HoneyPotTest is CommonTest {
    event ReceivedEther(address sender, uint256 amount);
    event DrainedEther(address to, uint256 amount);

    IAggregatorV3Source chainlink = IAggregatorV3Source(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    IMedian chronicle = IMedian(0x64DE91F5A373Cd4c28de3600cB34C7C6cE410C85);
    IPyth pyth = IPyth(0x4305FB66699C3B2702D4d05CF36551390A4c69C6);
    bytes32 pythPriceId = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;

    ChronicleMedianSourceAdapterMock chronicleMock = new ChronicleMedianSourceAdapterMock();

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
        honeyPot.resetPot();
        (, uint256 testhoneyPotBalanceReset) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalanceReset == 0);
        assertTrue(address(this).balance == balanceBefore);
    }

    function testCrackHoneyPot() public {
        // Create HoneyPot for the caller
        honeyPot.createHoneyPot{value: honeyPotBalance}();
        (, uint256 testhoneyPotBalance) = honeyPot.honeyPots(address(this));
        assertTrue(testhoneyPotBalance == honeyPotBalance);

        vm.prank(liquidator);
        vm.expectRevert("Liquidation price reached for this user");
        honeyPot.emptyHoneyPot(address(this)); // emptyHoneyPot now requires the creator's address

        // Simulate price change
        mockChainlinkPriceChange();

        // Unlock the latest value
        oevShare.unlockLatestValue();

        uint256 liquidatorBalanceBefore = liquidator.balance;

        vm.prank(liquidator);
        honeyPot.emptyHoneyPot(address(this)); // emptyHoneyPot now requires the creator's address

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
}
