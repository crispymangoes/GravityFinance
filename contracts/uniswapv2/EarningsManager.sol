// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "./interfaces/IPathOracle.sol";
import "./interfaces/IPriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
//TODO before any thing using the current pair cumulative, make sure getReserves() LastTimeStamp is equal to the current block.timestamp
//TODO maybe make it a modifier????
contract EarningsManager is Ownable {
    address public factory;
    IUniswapV2Factory Factory;
    address[] public swapPairs;
    mapping(address => uint256) public swapIndex;
    mapping(address => bool) public whitelist;
    address public PATHORACLE_ADDRESS;
    address public PRICEORACLE_ADDRESS;
    address public WBTC_ADDRESS;
    address public WETH_ADDRESS;

    struct oracle {
        uint[2] price0Cumulative;
        uint[2] price1Cumulative;
        uint32[2] timeStamp;
        uint8 index; // 0 or 1
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Gravity Finance: FORBIDDEN");
        _;
    }

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Caller is not in whitelist!");
        _;
    }

    constructor(address _factory) {
        swapPairs.push(address(0));
        factory = _factory;
        Factory = IUniswapV2Factory(factory);
    }

    function addSwapPair(address pairAddress) external onlyFactory {
        require(swapIndex[pairAddress] == 0, "Already have pair catalouged");
        swapPairs.push(pairAddress);
        swapIndex[pairAddress] = swapPairs.length;
    }

    function adjustWhitelist(address _address, bool _bool) external onlyOwner {
        whitelist[_address] = _bool;
    }

    function checkPrices(address pairAddress) public {
        IPriceOracle PriceOracle = IPriceOracle(PRICEORACLE_ADDRESS);
        //Assume there are only two swaps to get to the pool assets
        // swap wETH to GFI, and swap 1/2 GFI to Other

        //Two pair addresses to worry about is this one pairAddress, and the weth/gfi pair
        
        //Call get price to update prices on both pairs
        PriceOracle.getPrice(pairAddress);
        address firstAddress = Factory.getPair(Factory.weth(), Factory.gfi());
        PriceOracle.getPrice(firstAddress);

        //*****CHECK IF WE NEED TO LOOK AT ALTs
        //MAYBE THIS SHOULD JUST RETURN THE FULL ORACLE CUZ I ALSO NEED A WAY TO GET THE OTEHR INDEX TIMESTAMP
         oracle memory pairAOracle = PriceOracle.getOracle(firstAddress);
         oracle memory pairBOracle = PriceOracle.getOracle(pairAddress);
         uint pairATimeTillValid = pairAOracle.timeStamp[pairAOracle.index] + PriceOracle.priceValidStart();
         uint pairBTimeTillExpire = pairBOracle.timeStamp[pairBOracle.index] + PriceOracle.priceValidEnd();

         uint pairBTimeTillValid = pairBOracle.timeStamp[pairBOracle.index] + PriceOracle.priceValidStart();
         uint pairATimeTillExpire = pairAOracle.timeStamp[pairAOracle.index] + PriceOracle.priceValidEnd();
         //Check if weth/gfi price time till valid is greater than pairAddress time till expires
         if ( pairATimeTillValid > pairBTimeTillExpire) {
             //look at pairAddress other, and this should be less than 5 min till expiration, so report the max and min times
            //If that still doesn't work I think you can look at weth/gfi alt, not sure if you would ever make it here
         }
         // Check if pairAddress price time till valid is greater than weth/gfi time till expires
        else if ( pairBTimeTillValid > pairATimeTillExpire){
            //Now do all the previous logic above but swap the pairAddresses so
            //....
        }
       

        //finally, if both the if and else if above fail, I think you can just use the max time till valid, and the min time till expiration from the active prices and not need to look at alts
    }

    function _processEarnings(address pairAddress) internal {
        uint256 tokenBal;
        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();
        uint256 minAmount;
        uint256 timeTillValid;
        uint256 slippage = Factory.slippage();
        address[] memory path = new address[](2);
        uint256 earnings = IUniswapV2Pair(pairAddress).handleEarnings(); //Delegates Earnings to a holding contract, and holding approves earnings manager to spend earnings
        require(
            OZ_IERC20(Factory.weth()).transferFrom(
                IUniswapV2Pair(pairAddress).HOLDING_ADDRESS(),
                address(this),
                earnings
            ),
            "Failed to transfer wETH from holding to EM"
        );

        //So don't even need to call checkPrice here, this will fail if one of the prices isn't valid, so should make a seperate function that makes sure
        uint256[] memory amounts = new uint256[](2);
        //First swap wETH into GFI
        address firstPairAddress =
            Factory.getPair(Factory.weth(), Factory.gfi());
        (minAmount, timeTillValid) = IPriceOracle(PRICEORACLE_ADDRESS)
            .calculateMinAmount(
            Factory.weth(),
            slippage,
            earnings,
            firstPairAddress
        );
        require(timeTillValid == 0, "Price(s) not valid Call checkPrices()");
        path[0] = Factory.weth();
        path[1] = Factory.gfi();
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            earnings,
            minAmount,
            path,
            address(this),
            block.timestamp
        );

        //Swap 1/2 GFI into other asset
        tokenBal = amounts[1] / 2;
        (minAmount, timeTillValid) = IPriceOracle(PRICEORACLE_ADDRESS)
            .calculateMinAmount(Factory.gfi(), slippage, tokenBal, pairAddress);
        require(timeTillValid == 0, "Price(s) not valid Call checkPrice()");
        path[0] = Factory.gfi();
        if (IUniswapV2Pair(pairAddress).token0() == Factory.gfi()) {
            path[1] = IUniswapV2Pair(pairAddress).token1();
        } else {
            path[1] = IUniswapV2Pair(pairAddress).token0();
        }
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            tokenBal,
            minAmount,
            path,
            address(this),
            block.timestamp
        );

        OZ_IERC20 Token0 = OZ_IERC20(path[0]);
        OZ_IERC20 Token1 = OZ_IERC20(path[1]);

        uint256 minToken0 = (slippage * amounts[0]) / 100;
        uint256 minToken1 = (slippage * amounts[1]) / 100;
        Token0.approve(Factory.router(), amounts[0]);
        Token1.approve(Factory.router(), amounts[1]);

        IUniswapV2Router02(Factory.router()).addLiquidity(
            token0,
            token1,
            amounts[0],
            amounts[1],
            minToken0,
            minToken1,
            address(this),
            block.timestamp
        );

        IUniswapV2ERC20 LPtoken = IUniswapV2ERC20(pairAddress);
        require(
            LPtoken.burn(LPtoken.balanceOf(address(this))),
            "Failed to burn LP tokens"
        );
    }

    function processEarningsIntoLiquidity(address pairAddress)
        external
    /*Make a white list of addresses that can call this */
    {
        _processEarnings(pairAddress);
    }

    function processAssetsIntoLiquidity(uint256 startIndex, uint256 endIndex)
        external
        returns (uint256 lastIndex)
    {
        bool success;
        require(
            startIndex > 0,
            "Gravity Finance: Start index must be greater than zero"
        );
        for (uint256 i = startIndex; i < endIndex; i++) {
            _processEarnings(swapPairs[i]);
            if (!success) {
                lastIndex = i;
                break;
            }
        }
    }

    //TODO add function like _processEarnings, but make it use the minAmount as an input, so whitelist can call it even if pricing fails

    function processEarnings(address pairAddress, uint[2] memory minAmounts) external onlyWhitelist{
        uint256 tokenBal;
        address token0 = IUniswapV2Pair(pairAddress).token0();
        address token1 = IUniswapV2Pair(pairAddress).token1();
        uint256 slippage = Factory.slippage();
        address[] memory path = new address[](2);
        uint256 earnings = IUniswapV2Pair(pairAddress).handleEarnings(); //Delegates Earnings to a holding contract, and holding approves earnings manager to spend earnings
        require(
            OZ_IERC20(Factory.weth()).transferFrom(
                IUniswapV2Pair(pairAddress).HOLDING_ADDRESS(),
                address(this),
                earnings
            ),
            "Failed to transfer wETH from holding to EM"
        );

        //So don't even need to call checkPrice here, this will fail if one of the prices isn't valid, so should make a seperate function that makes sure
        uint256[] memory amounts = new uint256[](2);
        //First swap wETH into GFI
        path[0] = Factory.weth();
        path[1] = Factory.gfi();
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            earnings,
            minAmounts[0],
            path,
            address(this),
            block.timestamp
        );

        //Swap 1/2 GFI into other asset
        tokenBal = amounts[1] / 2;
        path[0] = Factory.gfi();
        if (IUniswapV2Pair(pairAddress).token0() == Factory.gfi()) {
            path[1] = IUniswapV2Pair(pairAddress).token1();
        } else {
            path[1] = IUniswapV2Pair(pairAddress).token0();
        }
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            tokenBal,
            minAmounts[1],
            path,
            address(this),
            block.timestamp
        );

        OZ_IERC20 Token0 = OZ_IERC20(path[0]);
        OZ_IERC20 Token1 = OZ_IERC20(path[1]);

        uint256 minToken0 = (slippage * amounts[0]) / 100;
        uint256 minToken1 = (slippage * amounts[1]) / 100;
        Token0.approve(Factory.router(), amounts[0]);
        Token1.approve(Factory.router(), amounts[1]);

        IUniswapV2Router02(Factory.router()).addLiquidity(
            token0,
            token1,
            amounts[0],
            amounts[1],
            minToken0,
            minToken1,
            address(this),
            block.timestamp
        );

        IUniswapV2ERC20 LPtoken = IUniswapV2ERC20(pairAddress);
        require(
            LPtoken.burn(LPtoken.balanceOf(address(this))),
            "Failed to burn LP tokens"
        );
    }
}
