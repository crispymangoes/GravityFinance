// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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
contract PriceOracle {
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

    function changeSlippage(uint256 _slippage) external{
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

}
