// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import '../interfaces/OZ_IERC20.sol';
import './interfaces/iGovernance.sol';
import './interfaces/IERC20.sol';
import './interfaces/IUniswapV2Pair.sol';
//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the 
contract EarningsManager {
    address public SWAP_ADDRESS;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address[2] public SWAP_PATH_token0_WETH;
    address[2] public SWAP_PATH_token0_WBTC;
    address[2] public SWAP_PATH_token1_WETH;
    address[2] public SWAP_PATH_token1_WBTC;

    OZ_IERC20 WETH;
    OZ_IERC20 WBTC;
    iGovernance Governor;
    IUniswapV2Pair LiquidityPool;

    modifier onlySwap() {
        require(msg.sender == SWAP_ADDRESS, "Gravity Finance: FORBIDDEN");
        _;
    }

    constructor(address governor, address weth, address wbtc) public {
        SWAP_ADDRESS = msg.sender;
        LiquidityPool = IUniswapV2Pair(SWAP_ADDRESS);
        GOVERNOR_ADDRESS = governor;
        Governor = iGovernance(GOVERNOR_ADDRESS);
        WETH_ADDRESS = weth;
        WBTC_ADDRESS = wbtc;
        WETH = OZ_IERC20(WETH_ADDRESS);
        WBTC = OZ_IERC20(WBTC_ADDRESS);
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
        OZ_IERC20 token0 = OZ_IERC20(LiquidityPool.token0());
        OZ_IERC20 token1 = OZ_IERC20(LiquidityPool.token1());

        if(address(token0) == WETH_ADDRESS || address(token0) == WBTC_ADDRESS){
            //Convert token1 into whatever token0 is
        }
        else if (address(token1) == WETH_ADDRESS || address(token1) == WBTC_ADDRESS){
            //convert token0 into whatever token1 is
        }
        else{
            //Neither token 0 nor 1 are WETH or WBTC, so convert both assets to WETH
        }
        //require(token0.approve(address(UniswapV2Router02), amountIn), 'approve failed.');


        Governor.depositFee(0,0);
    }

    function setSwapPath(address[] path_token0_weth, address[] path_token0_wbtc, address[] path_token1_weth, address[] path_token1_wbtc) external{

    }
}