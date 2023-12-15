// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {BoundedUnionSourceAdapter} from "oev-contracts/adapters/source-adapters/BoundedUnionSourceAdapter.sol";
import {BaseController} from "oev-contracts/controllers/BaseController.sol";
import {ChainlinkDestinationAdapter} from "oev-contracts/adapters/destination-adapters/ChainlinkDestinationAdapter.sol";
import {IAggregatorV3Source} from "oev-contracts/interfaces/chainlink/IAggregatorV3Source.sol";
import {IMedian} from "oev-contracts/interfaces/chronicle/IMedian.sol";
import {IPyth} from "oev-contracts/interfaces/pyth/IPyth.sol";

contract HoneyPotOval is BaseController, BoundedUnionSourceAdapter, ChainlinkDestinationAdapter {
    constructor(
        address chainlinkSource,
        address chronicleSource,
        address pythSource,
        bytes32 pythPriceId,
        uint8 decimals
    )
        BoundedUnionSourceAdapter(
            IAggregatorV3Source(chainlinkSource),
            IMedian(chronicleSource),
            IPyth(pythSource),
            pythPriceId,
            0.1e18
        )
        BaseController()
        ChainlinkDestinationAdapter(decimals)
    {}
}
