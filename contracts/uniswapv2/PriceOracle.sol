// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IUniswapV2Pair.sol';


contract PriceOracle is Ownable {
    struct Oracle{
        uint[2] cumulative0;
        uint[2] cumulative1;
        uint[2] timestamp;
        uint oldIndex;
    }

    mapping(address => Oracle) public pairPricing;


    function getMinAmount(address pair, uint amountIn, address assetIn) external returns(uint[] memory pricingInfo){


        //pricingInfo with three spots. pricingInfo[0] is the seconds till historical pricing data is valid, the other two are the minAmount for the asset
    }


}