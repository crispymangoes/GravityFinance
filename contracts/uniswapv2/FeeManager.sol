// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/IPathOracle.sol";
import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/iGovernance.sol";

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


    constructor(address _priceOracle, address _pathOracle) {
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
    function _convertTill(address tokenAddress, address stopAddress) internal{
        address currentAsset = tokenAddress;
        address nextAsset;
        address pairAddress;
        uint minAmount;
        uint timeTillValid;
        uint tokenBal;
        address[] memory path = new address[](2);
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

    function processAssetsIntowETH(uint startIndex, uint endIndex) external{
        for (uint i=startIndex; i < endIndex; i++){
            _convertTill(tokenList[i], WETH_ADDRESS);
        }
    }

    function finalConvertAndDeposit() external onlyOwner {
        _convertTill(WETH_ADDRESS, WBTC_ADDRESS);
        uint amountWETH = OZ_IERC20(WETH_ADDRESS).balanceOf(address(this));
        uint amountWBTC = OZ_IERC20(WBTC_ADDRESS).balanceOf(address(this));
        iGovernance(GOVERNANCE_ADDRESS).depositFee(amountWETH, amountWBTC);
    }

}