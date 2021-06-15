// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/IPathOracle.sol";
import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/iGovernance.sol";
//TODO instead of success bool, have it return the longest time till valid for the swap path
//TODO change logic so that instead of trying to swap an asset all the way to wETH, just step it one more asset along
// Then set up some beastly while loop that scans through all the assets, and swaps them if the price is valid, and updates price if necessary
// function will need to be called multiple times to work, and should really just swap everything into wETH and wBTC, then at the end swap the wBTC into wETH, and then swap half back into wBTC, or we could probs do the math
contract FeeManager is Ownable{
    address[] public tokenList;
    mapping(address => uint) public tokenIndex;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public FACTORY_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address public ROUTER_ADDRESS;
    address public GOVERNANCE_ADDRESS;
    address public PATHORACLE_ADDRESS;
    address public PRICEORACLE_ADDRESS;
    uint public slippage;


    constructor() {
        tokenList.push(address(0)); //populate the 0 index with the zero address

    }   

    /**
    * @dev Allows owner to manually convert tokens into wETH
    **/
    function convertTowETH(address tokenAddress) external onlyOwner{
        _convertTill(tokenAddress, WETH_ADDRESS);
    }
    /**
    * @dev When swap pairs are created, add their tokens to the tokenList if not already in it
    **/
    function catalougeTokens(address token0, address token1) external {
        if(tokenIndex[token0] == 0){
            tokenList.push(token0);
            tokenIndex[token0] = tokenList.length - 1;
        }

        if(tokenIndex[token1] == 0){
            tokenList.push(token1);
            tokenIndex[token1] = tokenList.length - 1;
        }
    }
    function _convertTill(address tokenAddress, address stopAddress) internal returns(bool success){
        address currentAsset = tokenAddress;
        address nextAsset;
        address pairAddress;
        uint minAmount;
        uint timeTillValid;
        uint tokenBal;
        address[] memory path = new address[](2);
        success = refreshPricePath(tokenAddress, stopAddress);
        if(success){
            while(currentAsset != stopAddress){//Should be capped to a max of 4 swaps based off current PathOracle.sol
                nextAsset = IPathOracle(PATHORACLE_ADDRESS).stepPath(currentAsset);
                pairAddress = IUniswapV2Factory(FACTORY_ADDRESS).getPair(currentAsset, nextAsset);
                tokenBal = OZ_IERC20(currentAsset).balanceOf(address(this));
                (minAmount, timeTillValid) = IPriceOracle(PRICEORACLE_ADDRESS).calculateMinAmount(currentAsset, slippage, tokenBal, pairAddress);
                require(timeTillValid == 0, "Price(s) not valid Call checkPrice()");
                OZ_IERC20(currentAsset).approve(ROUTER_ADDRESS, tokenBal);
                path[0] = currentAsset;
                path[1] = nextAsset;
                IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                    tokenBal,
                    minAmount,
                    path,
                    address(this),
                    block.timestamp
                );
                currentAsset = nextAsset; //Move to the next one
            }
        }
    }

    //TODO add an internal function that checks the entire path is valid before trying to swap

    function refreshPricePath(address tokenAddress, address stopAddress) public returns(bool success){
        address currentAsset = tokenAddress;
        address nextAsset;
        address pairAddress;
        uint minAmount;
        uint timeTillValid;
        uint tokenBal;
        address[] memory path = new address[](2);
        success = true;
        while(currentAsset != stopAddress){//Should be capped to a max of 4 swaps based off current PathOracle.sol
            nextAsset = IPathOracle(PATHORACLE_ADDRESS).stepPath(currentAsset);
            pairAddress = IUniswapV2Factory(FACTORY_ADDRESS).getPair(currentAsset, nextAsset);
            (,,timeTillValid) = IPriceOracle(PRICEORACLE_ADDRESS).getPrice(pairAddress);
            if (timeTillValid > 0){
                success = false;
            }
            currentAsset = nextAsset; //Move to the next one
        }
    }
    //Only owner?
    function processAssetsIntowETH(uint startIndex, uint endIndex) external returns(uint lastIndex){
        bool success;
        require(startIndex > 0, "Gravity Finance: Start index must be greater than zero");
        for (uint i=startIndex; i < endIndex; i++){
            success = _convertTill(tokenList[i], WETH_ADDRESS);
            if(!success){
                lastIndex = i;
                break;
            }
        }
    }

    function finalConvertAndDeposit() external onlyOwner {
        bool success = refreshPricePath(WETH_ADDRESS, WBTC_ADDRESS);

        _convertTill(WETH_ADDRESS, WBTC_ADDRESS);
        uint amountWETH = OZ_IERC20(WETH_ADDRESS).balanceOf(address(this));
        uint amountWBTC = OZ_IERC20(WBTC_ADDRESS).balanceOf(address(this));
        iGovernance(GOVERNANCE_ADDRESS).depositFee(amountWETH, amountWBTC);
    }

    //TODO add a function that allows whitelisted addresses to manually swap fees into wETH, setting their own min amounts
}