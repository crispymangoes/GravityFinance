// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/iGovernance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IPathOracle.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
contract EarningsManager {
    address public SWAP_ADDRESS;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address public ROUTER_ADDRESS;
    //address public LOGISTICS_ADDRESS;
    address[10] public swapPath; 
    mapping(address => uint) public lastCumulative0;
    mapping(address => uint) public lastCumulative1;
    uint lastTimeStamp;
    uint public swapCount;//Number of assets in swap path
    uint public slippage;


    OZ_IERC20 WETH;
    OZ_IERC20 WBTC;
    iGovernance Governor;
    IUniswapV2Pair LiquidityPool;
    IUniswapV2Factory Factory;
    IPathOracle PathOracle;
    

    modifier onlySwap() {
        require(msg.sender == SWAP_ADDRESS, "Gravity Finance: FORBIDDEN");
        _;
    }



    constructor(
        address governor,
        address weth,
        address wbtc,
        address router,
        address pathOracle
    ) public {
        SWAP_ADDRESS = msg.sender;
        LiquidityPool = IUniswapV2Pair(SWAP_ADDRESS);
        Factory = IUniswapV2Factory(LiquidityPool.factory());
        PathOracle = IPathOracle(pathOracle);
        PathOracle.appendPath(LiquidityPool.token0(), LiquidityPool.token1());
        GOVERNOR_ADDRESS = governor;
        Governor = iGovernance(GOVERNOR_ADDRESS);
        WETH_ADDRESS = weth;
        WBTC_ADDRESS = wbtc;
        WETH = OZ_IERC20(WETH_ADDRESS);
        WBTC = OZ_IERC20(WBTC_ADDRESS);
        ROUTER_ADDRESS = router;
        slippage = 95;

    }


    function updateSwapPath() external onlySwap {
        //Set the swapPath here by using path oracle to go through the path.
        //first need to check what the first swap of is if using asset A or asset B, if the first swap is the other asset, the use that asset to start the swapPath\
        address token0 = LiquidityPool.token0();
        address token1 = LiquidityPool.token1();
        if(PathOracle.stepPath(token0) == token1){
            swapPath[0] = token0;
            swapPath[1] = token1;
        }
        else if(PathOracle.stepPath(token1) == token0){
            swapPath[0] = token1;
            swapPath[1] = token0;
        }
        else{
            require(false, "Path does not exist!");
        }
        bool done;
        uint i = 2;
        swapCount = 2;
        while (i < 10){ //Max amount of assets in the swap is 10
            if(!done){
                if(swapPath[i-1] == WETH_ADDRESS || swapPath[i-1] == WBTC_ADDRESS){//If the previous path went to wETH or wBTC, then set done to true, this makes it so that the next iteration adds address(0) as the path
                    done = true;
                }
                swapPath[i] = PathOracle.stepPath(swapPath[i-1]);
                swapCount++;
            }
            else {
                swapPath[i] = address(0);
            }
        }
        updatePrice();
    }

    function checkPrice() external returns(uint timeTillValid) {
        if (lastTimeStamp + 600 < block.timestamp){
            //10 min window has already passed, so update all cumulatives
            timeTillValid = 300; //wait 5 min
            updatePrice();
        }
        else if (lastTimeStamp + 300 > block.timestamp){
            //Current prices have not matured, so wait until they do
            timeTillValid = (lastTimeStamp + 300) - block.timestamp;
        }
        else {
            //If we made it here, then we are in a time frame where the cumulatives are valid, so use them
            timeTillValid = 0; //return a zero, so that the calling function knows it is oaky to use the cumulatives to trade
        }
    }

    function updatePrice() internal {
        address pairAddress;
        for (uint i=0; i<swapCount-1; i++){
            pairAddress = Factory.getPair(swapPath[i], swapPath[i+1]);
            lastCumulative0[pairAddress] = IUniswapV2Pair(pairAddress).price0CumulativeLast();
            lastCumulative1[pairAddress] = IUniswapV2Pair(pairAddress).price1CumulativeLast();
        }
        lastTimeStamp = block.timestamp;
    }

    function calculateMinAmount(address from, address to, uint amount) internal returns(uint minAmount){
        //Make sure prices are up to date
        if(lastTimeStamp + 600 > block.timestamp && lastTimeStamp + 300 < block.timestamp){
            uint TWAP;
            IUniswapV2Pair Pair = IUniswapV2Pair(Factory.getPair(from, to));
            require(address(Pair) != address(0), "Pair does not exist!");
            if(Pair.token0() == from){ //Swapping token0 for token1 use cumulative0
                TWAP = (Pair.price0CumulativeLast() - lastCumulative0[address(Pair)]) / (block.timestamp - lastTimeStamp);
                minAmount = slippage * TWAP * amount / 100; //Pair price must be within 5% to swap
            }
        }
        else {
            updatePrice();
        }
    }

    function changeSlippage(uint _slippage) external onlySwap{
        slippage = _slippage;
    }

    function manageEarnings(address caller) external onlySwap {
        //Contract can use oracles to figure out the price of WETH and give the caller of the delegateFee function in the pool contract a 10 dollar reward
        //Could average the price from quickswap, sushiswap, and here
        //take any weth stored in contract, and swap half of it for asset A of the swap pool, and the other half for asset B
        //Make sure to remove the last zero for percision.
        //Then go through normal liquidity deposit route and recieve LP tokens
        //Once normal LP liquidity is done, then have this contract burn it's LP tokens, so it would call a special function in the pair contract that only this contract can call
        //Use LPToken.balanceOf(address(this))

        /** Basically manageFees but in reverse. If the last element isn't wETH, then go to the 2nd to last, and that should be wETH */
    }

    function manageFees() external onlySwap {
        address t0 = LiquidityPool.token0();
        address t1 = LiquidityPool.token1();
        OZ_IERC20 token0 = OZ_IERC20(t0);
        OZ_IERC20 token1 = OZ_IERC20(t1);
        OZ_IERC20 token;
        address pairAddress;
        uint tokenBal;
        address[] memory path = new address[](2);
        require(token0.balanceOf(address(this)) > 0 || token1.balanceOf(address(this)) > 0, "There are no fees to convert to wETH/wBTC" );
        for (uint i=0; i<swapCount-1; i++){
            token = OZ_IERC20(swapPath[i]);
            tokenBal = token.balanceOf(address(this));
            if(swapPath[i] == WETH_ADDRESS || swapPath[i] == WBTC_ADDRESS){tokenBal/2;} //Only swap half the tokens if swapping from wETH or wBTC
            require(
                    token.approve(ROUTER_ADDRESS, tokenBal),
                    "Failed to approve Router to spend tokens"
                );
            path[0] = swapPath[i]; //from
            path[1] = swapPath[i+1]; //to
            IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                    tokenBal,
                    calculateMinAmount(swapPath[i], swapPath[i+1], tokenBal),
                    path,
                    address(this),
                    block.timestamp
                );
        }
        token0 = OZ_IERC20(WETH_ADDRESS);
        token1 = OZ_IERC20(WBTC_ADDRESS);
        uint token0Bal = token0.balanceOf(address(this));
        uint token1Bal = token1.balanceOf(address(this));
        token0.approve(GOVERNOR_ADDRESS, token0Bal);
        token1.approve(GOVERNOR_ADDRESS, token1Bal);
        Governor.depositFee(token0Bal, token1Bal); 
    }
}
