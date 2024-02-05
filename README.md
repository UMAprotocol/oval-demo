# <h1 align="center"> Oval HoneyPot Demo </h1>

**This repository is a demonstration of the Oval system and a HoneyPot mechanism. It showcases how a backrunner can liquidate a position, in this particular case, how a HoneyPot can be emptied given a specific price change.**

## Introduction

The HoneyPot is a contract abstracting in a simple way a money market or any other contract that can be liquidated. The HoneyPot is initialized with a specific amount of funds and the Chainlink price at the creation of the pot. The HoneyPot can be subject to liquidation (emptyHoneyPot function) if the Chainlink price feed reports a value different from the initial price at the time of the HoneyPot's creation. The owner of the HoneyPot can reset the funds and the price at any time. It can support one honey per address calling the [`createHoneyPot`](https://github.com/UMAprotocol/oev-demo/blob/master/src/HoneyPot.sol#L31) function.

## Getting Started

To test the demo run the following commands:

```
forge install
export RPC_MAINNET=https://mainnet.infura.io/v3/<YOUR_INFURA_KEY>
forge test`
```

## Contracts Overview

- **HoneyPot**: This represents the honey pot, which can be emptied when the Chainlink price feed reports a value different from the initial price at the time of the honey pot's creation. The funds in the honey pot can also be reset by its owner.
- **ChainlinkOvalImmutable**: Serves as the oracle that retrieves prices from Chainlink. This is the simplest version of Oval that can be used to retrieve prices from Chainlink. It's pulled from the [Oval-Quickstart](https://github.com/UMAprotocol/oval-quickstart) repository.
- **ChainlinkOvalImmutable**: This is a simple example of a contract that can receive the Oval MEV-Share refunds for Oracle auction kickback.

## Deploy the Contracts

(Optional) Can be run against a fork with anvil by first running:

```bash
anvil --fork-url https://mainnet.infura.io/v3/<YOUR_KEY>
```

Run the following command to deploy the contracts:

```bash
 export PRIVATE_KEY=0xPUT_YOUR_PRIVATE_KEY_HERE # This account will do the deployment
 export SOURCE_ADDRESS=0x5f4ec3df9cbd43714fe2740f5e3616155c5b8419 # example Chainlink ETH/USD
 export LOCK_WINDOW=60 # How long each update is blocked for OEV auction to run.
 export MAX_TRAVERSAL=4 # How many iterations to look back for historic data.
 export UNLOCKER=0xPUT_YOUR_UNLOCKER_ADDRESS_HERE # Your address provided on Discord.
 export ETH_RPC_URL=PUT_YOUR_RPC_URL_HERE # Your network or fork RPC Url.

 forge script script/HoneyPot.s.sol --rpc-url $ETH_RPC_URL --broadcast
```
