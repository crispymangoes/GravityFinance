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
import "./libraries/UQ112x112.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
//TODO before any thing using the current pair cumulative, make sure getReserves() LastTimeStamp is equal to the current block.timestamp
//TODO maybe make it a modifier????
contract EarningsManager {
    using SafeMathUniswap for uint256;
    using UQ112x112 for uint224;
    uint8 public constant RESOLUTION = 112;
    struct uq112x112 {
        uint224 _x;
    }

    address public SWAP_ADDRESS;
    address public WETH_ADDRESS;
    address public WBTC_ADDRESS;
    address public GOVERNOR_ADDRESS;
    address public ROUTER_ADDRESS;
    //address public LOGISTICS_ADDRESS;
    address[10] public swapPath; //Paths will only ever be 4 long unless algo is upgraded
    mapping(address => uint256) public lastCumulative0;
    mapping(address => uint256) public lastCumulative1;
    uint32 public lastTimeStamp;
    uint256 public swapCount; //Number of assets in swap path
    uint256 public slippage;

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
        (address[10] memory _swapPath, uint256 _swapCount) =
            PathOracle.updateSwapPath(token0, token1);
        swapPath = _swapPath;
        swapCount = _swapCount;
        updatePrice();
    }

    function checkPrice() external returns (uint256 timeTillValid) {
        if (lastTimeStamp + 600 < block.timestamp) {
            //10 min window has already passed, so update all cumulatives
            timeTillValid = 300; //wait 5 min
            updatePrice();
        } else if (lastTimeStamp + 300 > block.timestamp) {
            //Current prices have not matured, so wait until they do
            timeTillValid = (lastTimeStamp + 300) - block.timestamp;
        } else {
            //If we made it here, then we are in a time frame where the cumulatives are valid, so use them
            timeTillValid = 0; //return a zero, so that the calling function knows it is oaky to use the cumulatives to trade
        }
    }

    function updatePrice() internal {
        address pairAddress;
        uint32 tempTimeStamp;
        for (uint256 i = 0; i < swapCount - 1; i++) {
            pairAddress = Factory.getPair(swapPath[i], swapPath[i + 1]);
            (
                uint256 price0Cumulative,
                uint256 price1Cumulative,
                uint32 timeStamp
            ) = currentCumulativePrices(pairAddress);
            lastCumulative0[pairAddress] = price0Cumulative;
            lastCumulative1[pairAddress] = price1Cumulative;
            tempTimeStamp = timeStamp;
        }
        lastTimeStamp = tempTimeStamp;
    }

    function calculateMinAmount(
        address from,
        address to,
        uint256 amount
    ) public view returns (uint256 minAmount) {
        uint256 TWAP;
        IUniswapV2Pair Pair = IUniswapV2Pair(Factory.getPair(from, to));
        address pairAddress = address(Pair);
        require(pairAddress != address(0), "Pair does not exist!");
        (uint256 price0Cumulative, uint256 price1Cumulative, uint32 timeStamp) =
            currentCumulativePrices(pairAddress);
        uint32 timeElapsed = timeStamp - lastTimeStamp;
        if (Pair.token0() == from) {
            TWAP = uint256((10**18 *uint224((price0Cumulative - lastCumulative0[address(Pair)]) /timeElapsed)) / 2**112);
            minAmount = (slippage * TWAP * amount) / 10**20; //Pair price must be within 5% to swap
        } else {
            TWAP = uint256((10**18 *uint224((price1Cumulative - lastCumulative1[address(Pair)]) /timeElapsed)) / 2**112);
            minAmount = (slippage * TWAP * amount) / 10**20; //Pair price must be within 5% to swap
        }
    }

    function changeSlippage(uint256 _slippage) external onlySwap {
        slippage = _slippage;
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

    function manageEarnings(address caller) external onlySwap {
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
            if (swapPath[index] != WETH_ADDRESS) {
                //Make sure we are starting with wETH
                continue;
            }
            token = OZ_IERC20(swapPath[index]);
            tokenBal = token.balanceOf(address(this));
            if (
                swapPath[i] == LiquidityPool.token0() ||
                swapPath[i] == LiquidityPool.token1()
            ) {
                tokenBal = tokenBal / 2;
            } //Only swap half the tokens if swapping from wETH or wBTC
            require(
                token.approve(ROUTER_ADDRESS, tokenBal),
                "Failed to approve Router to spend tokens"
            );
            path[0] = swapPath[index]; //from
            path[1] = swapPath[index - 1]; //to

            minAmount = calculateMinAmount(path[0], path[1], tokenBal);
            IUniswapV2Router02(ROUTER_ADDRESS).swapExactTokensForTokens(
                tokenBal,
                minAmount,
                path,
                address(this),
                block.timestamp
            );
        }
        OZ_IERC20 token0 = OZ_IERC20(LiquidityPool.token0());
        OZ_IERC20 token1 = OZ_IERC20(LiquidityPool.token0());
        uint256 token0Bal = token0.balanceOf(address(this));
        uint256 token1Bal = token1.balanceOf(address(this));
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
    }

    function manageFees() external onlySwap {
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

            minAmount = calculateMinAmount(path[0], path[1], tokenBal);
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
