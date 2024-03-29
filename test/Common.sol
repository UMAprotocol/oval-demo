// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

contract CommonTest is Test {
    address public constant owner = address(0x1);
    address public constant permissionedUnlocker = address(0x2);
    address public constant liquidator = address(0x3);
    address public constant account1 = address(0x4);
    address public constant account2 = address(0x5);
    address public constant random = address(0x6);
}
