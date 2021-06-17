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
//Add events so that The graph can track earnings going into the pool
contract EarningsManager is Ownable {
    address public factory;
    IUniswapV2Factory Factory;
    address[] public swapPairs;
    mapping(address => uint256) public swapIndex;
    mapping(address => bool) public whitelist;
    uint public amounts0;
    uint public amounts1;

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

    function validTimeWindow(address pairAddress) public returns (uint valid, uint expires){
        IPriceOracle PriceOracle = IPriceOracle(Factory.priceOracle());
        //Assume there are only two swaps to get to the pool assets
        // swap wETH to GFI, and swap 1/2 GFI to Other

        //Two pair addresses to worry about is this one pairAddress, and the weth/gfi pair
        
        //Call get price to update prices on both pairs
        PriceOracle.getPrice(pairAddress);
        address firstAddress = Factory.getPair(Factory.weth(), Factory.gfi());
        PriceOracle.getPrice(firstAddress);

        //*****CHECK IF WE NEED TO LOOK AT ALTs
        //MAYBE THIS SHOULD JUST RETURN THE FULL ORACLE CUZ I ALSO NEED A WAY TO GET THE OTEHR INDEX TIMESTAMP
        (uint pairACurrentTime, uint pairAOtherTime) = PriceOracle.getOracleTime(firstAddress);
        (uint pairBCurrentTime, uint pairBOtherTime) = PriceOracle.getOracleTime(pairAddress);
        
        uint pairATimeTillExpire = pairACurrentTime + PriceOracle.priceValidEnd();
        uint pairATimeTillValid = pairACurrentTime + PriceOracle.priceValidStart();
        uint pairBTimeTillExpire = pairBCurrentTime + PriceOracle.priceValidEnd();
        uint pairBTimeTillValid = pairBCurrentTime + PriceOracle.priceValidStart();
        //Check if weth/gfi price time till valid is greater than pairAddress time till expires
        if ( pairATimeTillValid > pairBTimeTillExpire) {
            //Check if pairBs other time till valid is less than pairAs current time till expire
            if (pairBOtherTime + PriceOracle.priceValidStart() < pairATimeTillExpire){
                //If this is true, then we want to use pairBs other saved timestamp
                pairBTimeTillExpire = pairBOtherTime + PriceOracle.priceValidEnd();
                pairBTimeTillValid = pairBOtherTime + PriceOracle.priceValidStart();
            }
            //potentially add an else statment, not sure if you would ever make it here though
        }
        // Check if pairAddress price time till valid is greater than weth/gfi time till expires
        else if ( pairBTimeTillValid > pairATimeTillExpire){
            //Check if pairAs other time till valid is less than pairBs current time till expire
            if (pairAOtherTime + PriceOracle.priceValidStart() < pairBTimeTillExpire){
                //If this is true, then we want to use pairAs other saved timestamp
                pairATimeTillExpire = pairAOtherTime + PriceOracle.priceValidEnd();
                pairATimeTillValid = pairAOtherTime + PriceOracle.priceValidStart();
            }
            //potentially add an else statment, not sure if you would ever make it here though
        }
        //Now set the min time till valid, and max time till expire
        if (pairATimeTillValid > pairBTimeTillValid){
            valid = pairATimeTillValid;
        }
        else {
            valid = pairBTimeTillValid;
        }
        if (pairATimeTillExpire < pairBTimeTillExpire){
            expires = pairATimeTillExpire;
        }
        else {
            expires = pairBTimeTillExpire;
        }
    }

    /**
    * @dev Will revert if prices are not valid, validTimeWindow() should be called before calling any functions that use price oracles to get min amounts
    * known inefficiency if target pair is wETH/GFI, it will trade all the wETH for GFI, then swap half the GFI back into wETH
    * I added in a 0.05% reduction to the amounts variables and that seemed to make things signifigantly closer to what they should be, much like the vanilla uniswap amounts were really close to the actual amounts you got
    **/
    //TODO add in check to see if it is the wETH GFI pair, then only do 1 1/2 swap m,aybe use a for loop for 2 iterations
    function oracleProcessEarnings(address pairAddress) external onlyWhitelist {
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
        uint256[] memory amounts = new uint256[](2);
        //First swap wETH into GFI
        address firstPairAddress =
            Factory.getPair(Factory.weth(), Factory.gfi());
        (minAmount, timeTillValid) = IPriceOracle(Factory.priceOracle())
            .calculateMinAmount(
            Factory.weth(),
            slippage,
            earnings,
            firstPairAddress
        );
        require(timeTillValid == 0, "Price(s) not valid Call validTimeWindow()");
        path[0] = Factory.weth();
        path[1] = Factory.gfi();
        OZ_IERC20(Factory.weth()).approve(Factory.router(), earnings);
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            earnings,
            minAmount,
            path,
            address(this),
            block.timestamp
        );

        //Swap 1/2 GFI into other asset
        (minAmount, timeTillValid) = IPriceOracle(Factory.priceOracle())
            .calculateMinAmount(Factory.gfi(), slippage, (amounts[1] / 2), pairAddress);
        require(timeTillValid == 0, "Price(s) not valid Call validTimeWindow()");
        path[0] = Factory.gfi();
        if (token0 == Factory.gfi()) {
            path[1] = token1;
        } else {
            path[1] = token0;
        }
        amounts[1] = amounts[1] * 9995 / 10000;
        OZ_IERC20(Factory.gfi()).approve(Factory.router(), (amounts[1] / 2));
        amounts = IUniswapV2Router02(Factory.router()).swapExactTokensForTokens(
            (amounts[1] / 2),
            minAmount,
            path,
            address(this),
            block.timestamp
        );


        uint256 minToken0 = (slippage * amounts[0]) / 100;
        uint256 minToken1 = (slippage * amounts[1]) / 100;
        OZ_IERC20(path[0]).approve(Factory.router(), amounts[0]);
        OZ_IERC20(path[1]).approve(Factory.router(), amounts[1]);
        amounts[1] = amounts[1] * 9995 / 10000;
        amounts0 = amounts[0];
        amounts1 = amounts[1];
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
        //Send remaining dust to dust pan
        //Token0.transfer(Factory.dustPan(), (amounts[0] - amountA));
        //Token1.transfer(Factory.dustPan(), (amounts[1] - amountB));
        
    }


    //Need to add same modifiations to this one that I added to the oracle one
    function manualProcessEarnings(address pairAddress, uint[2] memory minAmounts) external onlyWhitelist{
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

        (uint amountA, uint amountB,) = IUniswapV2Router02(Factory.router()).addLiquidity(
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
        //Send remaining dust to dust pan
        Token0.transfer(Factory.dustPan(), (amounts[0] - amountA));
        Token1.transfer(Factory.dustPan(), (amounts[1] - amountB));
    }

    /**
    * @dev should rarely be used, intended use is to collect dust and redistribute it to appropriate swap pools
    * Needed bc the price oracle earnings method has stack too deep errors when adding in transfer to Dust pan
    **/
    function adminWithdraw(address asset) external onlyOwner{
        //emit an event letting everyone know this was used
        OZ_IERC20 token = OZ_IERC20(asset);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
