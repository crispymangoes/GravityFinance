// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/iGovernance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/iLogistics.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
contract EarningsManager {
    address public SWAP_ADDRESS;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address public ROUTER_ADDRESS;
    address public LOGISTICS_ADDRESS;
    address[2] public SWAP_PATH_token0_WETH;
    address[2] public SWAP_PATH_token0_WBTC;
    address[2] public SWAP_PATH_token1_WETH;
    address[2] public SWAP_PATH_token1_WBTC;
    //Three swaps is the max you will have
    //SwapPath[3] public SWAP_PATH_EARNINGS; // the swap path to convert GFI earnings(wETH) to Liquidity assets
    //SwapPath[3] public SWAP_PATH_FEES; // the swap path to convert pool fees(token0 and token1) into wETH and wBTC

    OZ_IERC20 WETH;
    OZ_IERC20 WBTC;
    iGovernance Governor;
    IUniswapV2Pair LiquidityPool;
    iLogistics logistics = iLogistics(LOGISTICS_ADDRESS);
    

    modifier onlySwap() {
        require(msg.sender == SWAP_ADDRESS, "Gravity Finance: FORBIDDEN");
        _;
    }



    constructor(
        address governor,
        address weth,
        address wbtc,
        address router
    ) public {
        SWAP_ADDRESS = msg.sender;
        LiquidityPool = IUniswapV2Pair(SWAP_ADDRESS);
        GOVERNOR_ADDRESS = governor;
        Governor = iGovernance(GOVERNOR_ADDRESS);
        WETH_ADDRESS = weth;
        WBTC_ADDRESS = wbtc;
        WETH = OZ_IERC20(WETH_ADDRESS);
        WBTC = OZ_IERC20(WBTC_ADDRESS);
        ROUTER_ADDRESS = router;
        //logistics.createSwapPaths(LiquidityPool.factory(), WETH_ADDRESS, WBTC_ADDRESS, LiquidityPool.token0(), LiquidityPool.token1());
        //logistics.updateOracles(LiquidityPool.factory());

    }


    function updateSwapPaths(address factoryAddress) external onlySwap {
        logistics.createSwapPaths(LiquidityPool.factory(), WETH_ADDRESS, WBTC_ADDRESS, LiquidityPool.token0(), LiquidityPool.token1());
    }

    function manageEarnings(address caller) external onlySwap {
        //Contract can use oracles to figure out the price of WETH and give the caller of the delegateFee function in the pool contract a 10 dollar reward
        //Could average the price from quickswap, sushiswap, and here
        //take any weth stored in contract, and swap half of it for asset A of the swap pool, and the other half for asset B
        //Make sure to remove the last zero for percision.
        //Then go through normal liquidity deposit route and recieve LP tokens
        //Once normal LP liquidity is done, then have this contract burn it's LP tokens, so it would call a special function in the pair contract that only this contract can call
        //Use LPToken.balanceOf(address(this))
    }

    function manageFees() external onlySwap {
        //Function that takes all fees from asset swaps and converts them into half wETH and half wBTC

        //first check if any of the assets are wBTC or wETH, if one is, then swap the other one into that asset(wETH or wBTC)
        // If neither is, or the pair is both of them, then just exchange the one with a smaller amount into the other

        //Now that you have 1 asset, divide your total in 2, then remove the last 0 place. Then take one half and
        // convert it into wBTC and the other into wETH.

        //If one of the assets was wETH or wBTC, then convert the other into wETH or wBTC, then divide that in half and buy the other one you need

        //If the two assets are wBTC and wETH, then I think you do the same thing as the line above cuz they won't be evenly valued
        address t0 = LiquidityPool.token0();
        address t1 = LiquidityPool.token1();
        OZ_IERC20 token0 = OZ_IERC20(t0);
        OZ_IERC20 token1 = OZ_IERC20(t1);
        address pairAddress;
        uint256 token1Bal = token1.balanceOf(address(this));
        if (
            address(token0) == WETH_ADDRESS || address(token0) == WBTC_ADDRESS
        ) {
            //Convert token1 into whatever token0 is
            address[] memory path = new address[](2);
            pairAddress = IUniswapV2Factory(LiquidityPool.factory()).getPair(
                t1,
                t0
            );
            if (pairAddress != address(0)) {
                //Means we found a valid swap pair on Gravity

                require(
                    token1.approve(ROUTER_ADDRESS, token1Bal),
                    "Failed to approve Router to spend token1"
                );
                path[0] = t1;
                path[1] = t0;
                IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                    token1Bal,
                    0,
                    path,
                    address(this),
                    block.timestamp
                );
            }
        } else if (
            address(token1) == WETH_ADDRESS || address(token1) == WBTC_ADDRESS
        ) {
            //convert token0 into whatever token1 is
        } else {
            //Neither token 0 nor 1 are WETH or WBTC, so convert token1 into token0 or token0 into token1, depending on which one has a pair with wBTC or wETH
        }
        //require(token0.approve(address(UniswapV2Router02), amountIn), 'approve failed.');

        Governor.depositFee(0, 0);
    }

    //function setSwapPath(address[] path_token0_weth, address[] path_token0_wbtc, address[] path_token1_weth, address[] path_token1_wbtc) external{

    //}
}
