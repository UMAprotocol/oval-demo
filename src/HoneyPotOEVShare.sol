// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import {BoundedUnionSourceAdapter} from "oval-contracts/adapters/source-adapters/BoundedUnionSourceAdapter.sol";
import {BaseController} from "oval-contracts/controllers/BaseController.sol";
import {ChainlinkDestinationAdapter} from "oval-contracts/adapters/destination-adapters/ChainlinkDestinationAdapter.sol";
import {IAggregatorV3Source} from "oval-contracts/interfaces/chainlink/IAggregatorV3Source.sol";
import {IMedian} from "oval-contracts/interfaces/chronicle/IMedian.sol";
import {IPyth} from "oval-contracts/interfaces/pyth/IPyth.sol";

contract HoneyPotOVAL is BaseController, BoundedUnionSourceAdapter, ChainlinkDestinationAdapter {
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
