// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface NFTPricingInterface {

    function getEtimatePrice(
        address collection,
        uint256 tokenid,
        uint256 floorPrice
    ) external view returns (uint256, uint256);
    
}
