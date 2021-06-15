// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./libraries/UQ112x112.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is Ownable{
    using UQ112x112 for uint224;
    uint8 public constant RESOLUTION = 112;
    struct uq112x112 {
        uint224 _x;
    }

    struct oracle {
        uint[2] price0Cumulative;
        uint[2] price1Cumulative;
        uint32[2] timeStamp;
        uint8 index; // 0 or 1
    }

    mapping(address => oracle) public priceOracles; // Maps a pair address to a price oracle


    uint public priceValidStart;
    uint public priceValidEnd;



    constructor(uint _priceValidStart, uint _priceValidEnd) {
        require(_priceValidStart >= 300, "Price maturity must be greater than 300 seconds");
        require(_priceValidStart <= 3600, "Price maturity must be less than 3600 seconds");
        require(_priceValidStart * 2 == _priceValidEnd, "Price expiration must be equal to 2x price maturity");
        priceValidStart = _priceValidStart;
        priceValidEnd = _priceValidEnd;
    }

    function setTimingReq(uint _priceValidStart, uint _priceValidEnd) external onlyOwner{
        require(_priceValidStart >= 300, "Price maturity must be greater than 300 seconds");
        require(_priceValidStart <= 3600, "Price maturity must be less than 3600 seconds");
        require(_priceValidStart * 2 == _priceValidEnd, "Price expiration must be equal to 2x price maturity");
        priceValidStart = _priceValidStart;
        priceValidEnd = _priceValidEnd;
    }

    function getPrice(address pairAddress) public returns (uint price0Average, uint price1Average, uint timeTillValid) {
        uint8 index = priceOracles[pairAddress].index;
        uint8 otherIndex;
        uint8 tempIndex;
        if (index == 0){
            otherIndex = 1;
        }
        else {
            otherIndex = 0;
        }
        //Check if current index is expired
        if (priceOracles[pairAddress].timeStamp[index] + priceValidEnd < currentBlockTimestamp()) {
            (
                priceOracles[pairAddress].price0Cumulative[index],
                priceOracles[pairAddress].price1Cumulative[index],
                priceOracles[pairAddress].timeStamp[index]
            ) = currentCumulativePrices(pairAddress);   
            //Check if other index isnt expired
            if(priceOracles[pairAddress].timeStamp[otherIndex] + priceValidEnd > currentBlockTimestamp()){
                //If it hasn't expired, switch the indexes
                tempIndex = index;
                index = otherIndex;
                otherIndex = tempIndex;
            }
            //Now look at the current index, and figure out how long it is until it is valid
            require(priceOracles[pairAddress].timeStamp[index] + priceValidEnd > currentBlockTimestamp(), "Logic error index assigned incorrectly!");
            if (priceOracles[pairAddress].timeStamp[index] + priceValidStart > currentBlockTimestamp()){
                //Current prices have not matured, so wait until they do
                timeTillValid = (priceOracles[pairAddress].timeStamp[index] + priceValidStart) - currentBlockTimestamp();
            }
            else{
                timeTillValid = 0;
            } 
        }
        else {
            if (priceOracles[pairAddress].timeStamp[index] + priceValidStart > currentBlockTimestamp()){
                //Current prices have not matured, so wait until they do
                timeTillValid = (priceOracles[pairAddress].timeStamp[index] + priceValidStart) - currentBlockTimestamp();
            }
            else{
                timeTillValid = 0;
            } 
            if(priceOracles[pairAddress].timeStamp[otherIndex] + priceValidEnd < currentBlockTimestamp() && priceOracles[pairAddress].timeStamp[index] + priceValidStart < currentBlockTimestamp()){
                //If the other index is expired, and the current index is valid, then set other index = to current info
                (
                priceOracles[pairAddress].price0Cumulative[otherIndex],
                priceOracles[pairAddress].price1Cumulative[otherIndex],
                priceOracles[pairAddress].timeStamp[otherIndex]
            ) = currentCumulativePrices(pairAddress);
            }
        }
        if (timeTillValid == 0){//If prices are valid, set price0Average, and price1Average
            (uint256 price0Cumulative, uint256 price1Cumulative, uint32 timeStamp) =
            currentCumulativePrices(pairAddress);
            uint32 timeElapsed = timeStamp - priceOracles[pairAddress].timeStamp[index];
            price0Average = uint256((10**18 *uint224((price0Cumulative - priceOracles[pairAddress].price0Cumulative[index]) /timeElapsed)) / 2**112);
            price1Average =  uint256((10**18 *uint224((price1Cumulative - priceOracles[pairAddress].price1Cumulative[index]) /timeElapsed)) / 2**112);
        }
    }

    function calculateMinAmount(
        address from,
        uint256 slippage,
        uint256 amount,
        address pairAddress
    ) public returns (uint minAmount, uint timeTillValid) {
        require(pairAddress != address(0), "Pair does not exist!");
        require(slippage <= 100, "Slippage should be a number between 0 -> 100");
        (,, timeTillValid) = getPrice(pairAddress);
        if (timeTillValid == 0){
            uint8 index = priceOracles[pairAddress].index;
            uint256 TWAP;
            IUniswapV2Pair Pair = IUniswapV2Pair(pairAddress);
            (uint256 price0Cumulative, uint256 price1Cumulative, uint32 timeStamp) =
                currentCumulativePrices(pairAddress);
            uint32 timeElapsed = timeStamp - priceOracles[pairAddress].timeStamp[index];
            if (Pair.token0() == from) {
                TWAP = uint256((10**18 *uint224((price0Cumulative - priceOracles[pairAddress].price0Cumulative[index]) /timeElapsed)) / 2**112);
                minAmount = (slippage * TWAP * amount) / 10**20; //Pair price must be within slippage req
            } else {
                TWAP = uint256((10**18 *uint224((price1Cumulative - priceOracles[pairAddress].price1Cumulative[index]) /timeElapsed)) / 2**112);
                minAmount = (slippage * TWAP * amount) / 10**20; //Pair price must be within slippage req
            }
        }
    }

    function currentBlockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp % 2**32);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices(address pair)
        internal
        view
        returns (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        )
    {
        blockTimestamp = currentBlockTimestamp();
        price0Cumulative = IUniswapV2Pair(pair).price0CumulativeLast();
        price1Cumulative = IUniswapV2Pair(pair).price1CumulativeLast();

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) =
            IUniswapV2Pair(pair).getReserves();
        if (blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            // addition overflow is desired
            // counterfactual
            price0Cumulative +=
                uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) *
                timeElapsed;
            price1Cumulative +=
                uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) *
                timeElapsed;
        }
    }

}
