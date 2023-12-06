// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MainContract {
    uint totalCollections = 7;

    address[] nftDeployAddrs = [
        0x10B8b56D53bFA5e374f38e6C0830BAd4ebeE33E6,//Azuki
        0xE29F8038d1A3445Ab22AD1373c65eC0a6E1161a4,//BAYC
        0x05fdBac96C17026c71681150aa44Cbd0DDDd3374,//CloneX
        0xbDcF4B6693e344115b951c4796e8622A66Cdb728,//CoolCats
        0xbb1594Cc5C456541B02A24a9132B070B385B7035,//CryptoPunks
        0x4fD837940Fc2D7d800DC328373672f1Ac3250a21,//Doodles
        0x09e8617f391c54530CC2D3762ceb1dA9F840c5a3//MAYC
    ];

    address[] feedDeployAddrs = [
        0x9F6d70CDf08d893f0063742b51d3E9D1e18b7f74,//Azuki
        0xB677bfBc9B09a3469695f40477d05bc9BcB15F50,//BAYC
        0xE42f272EdF974e9c70a6d38dCb47CAB2A28CED3F,//CloneX
        0x13F38938A18ff26394c5ac8df94E349A97AaAb4e,//CoolCats
        0x5c13b249846540F81c093Bc342b5d963a7518145,//CryptoPunks
        0xEDA76D1C345AcA04c6910f5824EC337C8a8F36d2,//Doodles
        0xCbDcc8788019226d09FcCEb4C727C48A062D8124//MAYC
    ];

    mapping(address => uint) nftToFeed;
    
    constructor(){
        for(uint i = 0;i < totalCollections;i++){
            nftToFeed[nftDeployAddrs[i]] = i + 1;
        }
    }

    function getFloorPrice(address _deployAddress) public view returns (int) {
        require(nftToFeed[_deployAddress] > 0,"Error: could not find corresponding nft collection.");
        address feedAddress = feedDeployAddrs[nftToFeed[_deployAddress] - 1];
        AggregatorV3Interface NFTFloorPriceFeed = AggregatorV3Interface(feedAddress);
        ( /*uint80 roundID*/,int floorPrice,/*uint startedAt*/,/*uint timeStamp*/,/*uint80 answeredInRound*/) = NFTFloorPriceFeed.latestRoundData();
        return floorPrice;
    }
}