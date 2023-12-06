// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFTFloorPriceFeeds {
    AggregatorV3Interface internal NFTFloorPriceFeed;

    address constant BAYC = 0xB677bfBc9B09a3469695f40477d05bc9BcB15F50;

    constructor() {
        NFTFloorPriceFeed = AggregatorV3Interface(BAYC);
    }

    function getLatestPrice() public view returns (int) {
        ( /*uint80 roundID*/,int floorPrice,/*uint startedAt*/,/*uint timeStamp*/,/*uint80 answeredInRound*/) = NFTFloorPriceFeed.latestRoundData();
        return floorPrice;
    }

}