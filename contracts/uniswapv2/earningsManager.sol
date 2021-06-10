// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/OZ_IERC20.sol";
import "./libraries/SafeMath.sol";
import "./interfaces/iGovernance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2ERC20.sol";
import "./interfaces/IPathOracle.sol";
import "./interfaces/IPriceOracle.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
//TODO before any thing using the current pair cumulative, make sure getReserves() LastTimeStamp is equal to the current block.timestamp
//TODO maybe make it a modifier????
contract EarningsManager {
    using SafeMathUniswap for uint256;

    address public SWAP_ADDRESS;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address public ROUTER_ADDRESS;
    //address public FEE_TO_SETTER_ADDRESS;
    //address public LOGISTICS_ADDRESS;
    address[10] public swapPath; //Paths will only ever be 4 long unless algo is upgraded
    uint256 public swapCount; //Number of assets in swap path
    uint256 public slippage;

    OZ_IERC20 WETH;
    OZ_IERC20 WBTC;
    iGovernance Governor;
    IUniswapV2Pair LiquidityPool;
    IUniswapV2Factory Factory;
    IPathOracle PathOracle;
    IPriceOracle PriceOracle;

    modifier onlySwap() {
        require(msg.sender == SWAP_ADDRESS, "Gravity Finance: FORBIDDEN");
        _;
    }

    constructor(
        address governor,
        address weth,
        address wbtc,
        address router,
        address pathOracle,
        address priceOracle//,
        //address feeToSetter
    ) public {
        SWAP_ADDRESS = msg.sender;
        LiquidityPool = IUniswapV2Pair(SWAP_ADDRESS);
        Factory = IUniswapV2Factory(LiquidityPool.factory());
        PathOracle = IPathOracle(pathOracle);
        PathOracle.appendPath(LiquidityPool.token0(), LiquidityPool.token1());
        PriceOracle = IPriceOracle(priceOracle);
        GOVERNOR_ADDRESS = governor;
        Governor = iGovernance(GOVERNOR_ADDRESS);
        WETH_ADDRESS = weth;
        WBTC_ADDRESS = wbtc;
        WETH = OZ_IERC20(WETH_ADDRESS);
        WBTC = OZ_IERC20(WBTC_ADDRESS);
        ROUTER_ADDRESS = router;
        slippage = 95;
        //FEE_TO_SETTER_ADDRESS = feeToSetter;
    }

    function changePriceOracle() external onlySwap{}
    function changePathOracle() external onlySwap{}

    function checkPricing() external returns(bool allPricesValid, uint maxTime){
        //Function that goes through swap path and updates every pricing, and confirms that all prices are valid
        //use getPrice
        require(swapCount > 0, "swapPath is not set!");
        address pairAddress;
        allPricesValid = true;
        uint timeTillValid;
        for (uint256 i = 0; i < swapCount - 1; i++) {
            pairAddress = Factory.getPair(swapPath[i], swapPath[i+1]);
            (,, timeTillValid) = PriceOracle.getPrice(pairAddress);
            if(timeTillValid != 0){
                allPricesValid = false;
                if (timeTillValid > maxTime) {
                    maxTime = timeTillValid;
                }    
            }
        }

    }

    function updateSwapPath() external onlySwap {
        //Set the swapPath here by using path oracle to go through the path.
        //first need to check what the first swap of is if using asset A or asset B, if the first swap is the other asset, the use that asset to start the swapPath\

        address token0 = LiquidityPool.token0();
        address token1 = LiquidityPool.token1();
        (address[10] memory _swapPath, uint256 _swapCount) =
            PathOracle.updateSwapPath(token0, token1);
        swapPath = _swapPath;
        swapCount = _swapCount;
    }



    function changeSlippage(uint256 _slippage) external onlySwap {
        slippage = _slippage;
    }

    function manageEarnings() external onlySwap returns(uint timeTillValid){
        OZ_IERC20 token;
        address pairAddress;
        uint256 tokenBal;
        address[] memory path = new address[](2);
        uint256 minAmount;
        uint256 index;
        require(
            OZ_IERC20(WETH_ADDRESS).balanceOf(address(this)) > 0,
            "There are no earnings to convert to pool assets"
        );
        for (uint256 i = 0; i < swapCount - 1; i++) {
            index = (swapCount - 1) - i;
            if (swapPath[index] == WBTC_ADDRESS && i == 0) {
                //Make sure we are starting with wETH
                continue;
            }
            token = OZ_IERC20(swapPath[index]);
            tokenBal = token.balanceOf(address(this));
            if (
                swapPath[index] == LiquidityPool.token0() ||
                swapPath[index] == LiquidityPool.token1()
            ) {
                tokenBal = tokenBal / 2;
            } //Only swap half the tokens if swapping from wETH or wBTC
            require(
                token.approve(ROUTER_ADDRESS, tokenBal),
                "Failed to approve Router to spend tokens"
            );
            path[0] = swapPath[index]; //from
            path[1] = swapPath[index - 1]; //to
            pairAddress = Factory.getPair(path[0], path[1]);
            (minAmount, timeTillValid) = PriceOracle.calculateMinAmount(path[0], slippage, tokenBal, pairAddress);
            require(timeTillValid == 0, "Price(s) not valid Call checkPrice()");
            IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                tokenBal,
                minAmount,
                path,
                address(this),
                block.timestamp
            );
        }
        OZ_IERC20 token0 = OZ_IERC20(LiquidityPool.token0());
        OZ_IERC20 token1 = OZ_IERC20(LiquidityPool.token1());
        uint token0Bal = token0.balanceOf(address(this));
        uint token1Bal = token1.balanceOf(address(this));
        
        uint256 minToken0 = (slippage * token0Bal) / 100;
        uint256 minToken1 = (slippage * token1Bal) / 100;
        token0.approve(ROUTER_ADDRESS, token0Bal);
        token1.approve(ROUTER_ADDRESS, token1Bal);
        
        IUniswapV2Router02(ROUTER_ADDRESS).addLiquidity(
            LiquidityPool.token0(),
            LiquidityPool.token1(),
            token0Bal,
            token1Bal,
            minToken0,
            minToken1,
            address(this),
            block.timestamp
        );
        
        IUniswapV2ERC20 LPtoken = IUniswapV2ERC20(SWAP_ADDRESS);
        require(
            LPtoken.burn(LPtoken.balanceOf(address(this))),
            "Failed to burn LP tokens"
        );
        //Send scraps to feeToSetter
        //token0.transfer(FEE_TO_SETTER_ADDRESS, token0.balanceOf(address(this)));
        //token1.transfer(FEE_TO_SETTER_ADDRESS, token1.balanceOf(address(this)));
    }

    function manageFees() external onlySwap returns(uint timeTillValid){
        address t0 = LiquidityPool.token0();
        address t1 = LiquidityPool.token1();
        OZ_IERC20 token0 = OZ_IERC20(t0);
        OZ_IERC20 token1 = OZ_IERC20(t1);
        OZ_IERC20 token;
        address pairAddress;
        uint256 tokenBal;
        address[] memory path = new address[](2);
        uint256 minAmount;
        require(
            token0.balanceOf(address(this)) > 0 ||
                token1.balanceOf(address(this)) > 0,
            "There are no fees to convert to wETH/wBTC"
        );
        for (uint256 i = 0; i < swapCount - 1; i++) {
            token = OZ_IERC20(swapPath[i]);
            tokenBal = token.balanceOf(address(this));
            if (swapPath[i] == WETH_ADDRESS || swapPath[i] == WBTC_ADDRESS) {
                tokenBal = tokenBal / 2;
            } //Only swap half the tokens if swapping from wETH or wBTC
            require(
                token.approve(ROUTER_ADDRESS, tokenBal),
                "Failed to approve Router to spend tokens"
            );
            path[0] = swapPath[i]; //from
            path[1] = swapPath[i + 1]; //to
            pairAddress = Factory.getPair(path[0], path[1]);
            (minAmount, timeTillValid) = PriceOracle.calculateMinAmount(path[0], slippage, tokenBal, pairAddress);
            require(timeTillValid == 0, "Price(s) not valid Call checkPrice()");
            IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                tokenBal,
                minAmount,
                path,
                address(this),
                block.timestamp
            );
        }
        token0 = OZ_IERC20(WETH_ADDRESS);
        token1 = OZ_IERC20(WBTC_ADDRESS);
        uint256 token0Bal = token0.balanceOf(address(this));
        uint256 token1Bal = token1.balanceOf(address(this));
        token0.approve(GOVERNOR_ADDRESS, token0Bal);
        token1.approve(GOVERNOR_ADDRESS, token1Bal);
        Governor.depositFee(token0Bal, token1Bal);
    }

}
