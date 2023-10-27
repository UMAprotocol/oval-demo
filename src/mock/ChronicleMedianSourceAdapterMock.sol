// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {ChronicleMedianSourceAdapter} from "oev-contracts/adapters/source-adapters/ChronicleMedianSourceAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ChronicleMedianSourceAdapterMock is
    Ownable,
    ChronicleMedianSourceAdapter
{
    constructor() ChronicleMedianSourceAdapter(address(0)) {}

    uint256 public value;
    uint256 public age;

    function getLatestSourceData()
        public
        view
        virtual
        override
        returns (int256, uint256)
    {
        return (SafeCast.toInt256(value), age);
    }

    function setLatestSourceData(
        uint256 _value,
        uint256 _age
    ) public onlyOwner {
        value = _value;
        age = _age;
    }
}
