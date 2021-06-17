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
contract FeeManager is Ownable {
    address[] public tokenList;
    mapping(address => uint256) public tokenIndex;
    address public factory;
    mapping(address => bool) public whitelist;
    IUniswapV2Factory Factory;

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Caller is not in whitelist!");
        _;
    }

    constructor(address _factory) {
        tokenList.push(address(0)); //populate the 0 index with the zero address
        factory = _factory;
        Factory = IUniswapV2Factory(factory);
    }

    function adjustWhitelist(address _address, bool _bool) external onlyOwner {
        whitelist[_address] = _bool;
    }

    /**
     * @dev When swap pairs are created, add their tokens to the tokenList if not already in it
     **/
    function catalougeTokens(address token0, address token1) external {
        if (tokenIndex[token0] == 0) {
            tokenList.push(token0);
            tokenIndex[token0] = tokenList.length - 1;
        }

        if (tokenIndex[token1] == 0) {
            tokenList.push(token1);
            tokenIndex[token1] = tokenList.length - 1;
        }
    }

    function deposit() external onlyWhitelist {
        OZ_IERC20 weth = OZ_IERC20(Factory.weth());
        OZ_IERC20 wbtc = OZ_IERC20(Factory.wbtc());
        uint256 amountWETH = weth.balanceOf(address(this));
        uint256 amountWBTC = wbtc.balanceOf(address(this));
        weth.approve(Factory.governor(), amountWETH);
        wbtc.approve(Factory.governor(), amountWBTC);
        iGovernance(Factory.governor()).depositFee(amountWETH, amountWBTC);
    }

    function validTimeWindow(address asset) external returns(uint valid, uint expiration){
        IPriceOracle PriceOracle = IPriceOracle(Factory.priceOracle());
        address nextAsset = IPathOracle(Factory.pathOracle()).stepPath(asset);
        address pairAddress = Factory.getPair(asset, nextAsset);
        
        //Call get price
        PriceOracle.getPrice(pairAddress);

        (uint pairCurrentTime,) = PriceOracle.getOracleTime(pairAddress);
        
        expiration = pairCurrentTime + PriceOracle.priceValidEnd();
        valid = pairCurrentTime + PriceOracle.priceValidStart();
    }

    function oracleStepSwap(address asset, bool half) external onlyWhitelist{
        uint tokenBal = OZ_IERC20(asset).balanceOf(address(this));
        if(half){
            tokenBal / 2;
        }
        address[] memory path = new address[](2);
        address nextAsset = IPathOracle(Factory.pathOracle()).stepPath(asset);
        address pairAddress = Factory.getPair(asset, nextAsset);
        (uint minAmount, uint timeTillValid) = IPriceOracle(Factory.priceOracle())
            .calculateMinAmount(asset, Factory.slippage(), tokenBal, pairAddress);
        require(timeTillValid == 0, "Price(s) not valid Call checkPrice()");
        OZ_IERC20(asset).approve(Factory.router(), tokenBal);
        path[0] = asset;
        path[1] = nextAsset;
        IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            tokenBal,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
    * @dev just like oracleStepSwap, but caller manually enters the minAmount, must be called by a whitelisted address
    * Potential Exploit: If malicous address is on whitelist, they can set a low minAmount, and then force contract to make bad swaps for their gain
    **/
    function manualStepSwap(address asset, bool half, uint minAmount) external onlyWhitelist{

        uint tokenBal = OZ_IERC20(asset).balanceOf(address(this));
        if(half){
            tokenBal / 2;
        }
        tokenBal = OZ_IERC20(asset).balanceOf(address(this));
        address[] memory path = new address[](2);
        address nextAsset = IPathOracle(Factory.pathOracle()).stepPath(asset);
        OZ_IERC20(asset).approve(Factory.router(), tokenBal);
        path[0] = asset;
        path[1] = nextAsset;
        IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            tokenBal,
            minAmount,
            path,
            address(this),
            block.timestamp
        );
    }

    function adminWithdraw(address asset) external onlyOwner{
        //emit an event letting everyone know this was used
        OZ_IERC20 token = OZ_IERC20(asset);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
