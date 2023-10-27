
# <h1 align="center"> OEV Share HoneyPot Demo </h1>

**This repository is a demonstration of the OEV Share system and a HoneyPot mechanism. It showcases how a backrunner can liquidate a position, in this particular case, how a HoneyPot can be emptied given a specific price change.**

![Github Actions](https://github.com/UMAprotocol/oev-demo/workflows/CI/badge.svg)

## Introduction

The HoneyPot mechanism is a unique setup where funds are kept in a contract that is designed to be emptied out based on specific criteria, in this case, a change in the price from an oracle.

## Getting Started

To test the demo run the following commands:
```
forge install
export RPC_MAINNET=https://mainnet.infura.io/v3/<YOUR_INFURA_KEY>
forge test` 
```

## Contracts Overview

-   **HoneyPot**: Represents the honey pot, which can be emptied when a price oracle returns a value different from a pre-defined liquidation price. The honey pot's funds can also be reset by its owner.
    
-   **HoneyPotOEVShare**: Acts as the oracle which retrieves prices from various sources like Chainlink, Chronicle, and Pyth.
    
-   **Test Contract**: Sets up the environment, including simulating price changes and testing the mechanisms for creating and emptying the HoneyPot.

## Deploy the Contracts

Can be run against a fork with anvil:
``` bash
anvil --fork-url https://mainnet.infura.io/v3/<YOUR_KEY>
```

Then:

``` bash
 export MNEMONIC="test test test test test test test test test test test junk"
 export DEPLOYER_WALLET=$(cast wallet address --mnemonic "$MNEMONIC")
 export ETH_RPC_URL="http://127.0.0.1:8545"
 
 forge script script/HoneyPot.s.sol \
          --fork-url $ETH_RPC_URL \
          --mnemonics "$MNEMONIC" \
          --sender $DEPLOYER_WALLET \
          --broadcast
```