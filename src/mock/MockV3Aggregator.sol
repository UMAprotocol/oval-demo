pragma solidity ^0.8.0;

import {IAggregatorV3} from "oval-contracts/interfaces/chainlink/IAggregatorV3.sol";

contract MockV3Aggregator is IAggregatorV3 {

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
  
  address public immutable aggregator;
  uint256 public constant version = 0;

  uint8 public override decimals;
  int256 public override latestAnswer;
  uint256 public override latestTimestamp;
  uint256 public latestRound;

  mapping(uint256 => int256) public getAnswer;
  mapping(uint256 => uint256) public getTimestamp;
  mapping(uint256 => uint256) private getStartedAt;

  constructor(uint8 _decimals, int256 _initialAnswer) {
    decimals = _decimals;
    updateAnswer(_initialAnswer);
    aggregator = address(this); // For simplicity, we set the aggregator address to the contract address
  }

  function updateAnswer(int256 _answer) internal {
    latestAnswer = _answer;
    latestTimestamp = block.timestamp;
    latestRound++;
    getAnswer[latestRound] = _answer;
    getTimestamp[latestRound] = block.timestamp;
    getStartedAt[latestRound] = block.timestamp;

    emit AnswerUpdated(_answer, latestRound, block.timestamp);
  }

  // This function is part of the AccessControlledOffchainAggregator interface. It is used to
  // update the new price and look like a transmit function from a real Chainlink Aggregator
  function transmit(
    bytes calldata _report, // _report should be the ABI encoded int256 new answer
    bytes32[] calldata _rs, bytes32[] calldata _ss, bytes32 _rawVs
  )
    external
  {
    int256 newAnswer = abi.decode(_report, (int256));
    updateAnswer(newAnswer);
  }

  function updateRoundData(uint80 _roundId, int256 _answer, uint256 _timestamp, uint256 _startedAt) public {
    latestRound = _roundId;
    latestAnswer = _answer;
    latestTimestamp = _timestamp;
    getAnswer[latestRound] = _answer;
    getTimestamp[latestRound] = _timestamp;
    getStartedAt[latestRound] = _startedAt;
  }

  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (_roundId, getAnswer[_roundId], getStartedAt[_roundId], getTimestamp[_roundId], _roundId);
  }

  function latestRoundData()
    external
    view
    override
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
  {
    return (
      uint80(latestRound),
      getAnswer[latestRound],
      getStartedAt[latestRound],
      getTimestamp[latestRound],
      uint80(latestRound)
    );
  }
}
