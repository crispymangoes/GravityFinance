// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "../interfaces/OZ_IERC20.sol";
import "./interfaces/iGovernance.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

//TODO make it so that the governance address is passed into the factory on craetion, then it is relayed to the pair contract and to this contract, and initialized in the
contract Logistics {

    //modifier sufficientTWAP(){
    //    require(block.timestamp >= ());
    //}
    struct PathOracles {
        mapping(address => uint) pairAddressToCumlative0;
        mapping(address => uint) pairAddressToCumlative1;
        uint256 timestamp;
    }
    struct SwapPath {
        address[3] to;
        bool fullOrHalf; // if true, convert all the asset into the to asset, if half, then convert half into the to asset
    }

    PathOracles public EarningsOracle;
    PathOracles public FeesOracle;

    function createSwapPaths(address factoryAddress, address WETH_ADDRESS, address WBTC_ADDRESS, address t0, address t1) external {
        SwapPath[3] memory SWAP_PATH_EARNINGS; // the swap path to convert GFI earnings(wETH) to Liquidity assets
        SwapPath[3] memory SWAP_PATH_FEES; // the swap path to convert pool fees(token0 and token1) into wETH and wBTC
        address pairAddress;
        //Figure out paths
        if (t0 == WETH_ADDRESS){
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, t1, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t1, WETH_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (t1 == WETH_ADDRESS){
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, t0, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t0, WETH_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (t0 == WBTC_ADDRESS){
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });
            SWAP_PATH_EARNINGS[1] = SwapPath({
                to: [WBTC_ADDRESS, t1, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t1, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [WBTC_ADDRESS, WETH_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (t1 == WBTC_ADDRESS){
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });
            SWAP_PATH_EARNINGS[1] = SwapPath({
                to: [WBTC_ADDRESS, t0, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t0, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [WBTC_ADDRESS, WETH_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (IUniswapV2Factory(factoryAddress).getPair(WETH_ADDRESS, t0) != address(0)){//Check if t0 has a pair with WETH
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, t0, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_EARNINGS[1] = SwapPath({
                to: [t0, t1, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t1, t0, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [t0, WETH_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[2] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (IUniswapV2Factory(factoryAddress).getPair(WETH_ADDRESS, t1) != address(0)){//Check if t1 has a pair with WETH
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, t1, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_EARNINGS[1] = SwapPath({
                to: [t1, t0, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t0, t1, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [t1, WETH_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[2] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else if (IUniswapV2Factory(factoryAddress).getPair(WBTC_ADDRESS, t0) != address(0)){//Check if t0 has a pair with WBTC
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, t0],
                fullOrHalf: true
            });

            SWAP_PATH_EARNINGS[2] = SwapPath({
                to: [t0, t1, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t1, t0, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [t0, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[2] = SwapPath({
                to: [WBTC_ADDRESS, WETH_ADDRESS, address(0)],
                fullOrHalf: false
            });
            
        }
        else if (IUniswapV2Factory(factoryAddress).getPair(WBTC_ADDRESS, t1) != address(0)){//Check if t1 has a pair with WBTC
            SWAP_PATH_EARNINGS[0] = SwapPath({
                to: [WETH_ADDRESS, WBTC_ADDRESS, t1],
                fullOrHalf: true
            });

            SWAP_PATH_EARNINGS[2] = SwapPath({
                to: [t1, t0, address(0)],
                fullOrHalf: false
            });

            SWAP_PATH_FEES[0] = SwapPath({
                to: [t0, t1, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[1] = SwapPath({
                to: [t1, WBTC_ADDRESS, address(0)],
                fullOrHalf: true
            });

            SWAP_PATH_FEES[2] = SwapPath({
                to: [WBTC_ADDRESS, WETH_ADDRESS, address(0)],
                fullOrHalf: false
            });
        }
        else{
            //Could emit something here
        }
    }
    function updateOracles(address factoryAddress) external {
        //In charge of creating price oracles
        SwapPath[3] memory SWAP_PATH_EARNINGS; // the swap path to convert GFI earnings(wETH) to Liquidity assets
        SwapPath[3] memory SWAP_PATH_FEES; // the swap path to convert pool fees(token0 and token1) into wETH and wBTC
        address pairAddress;
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 2; j++) {
                if (SWAP_PATH_EARNINGS[i].to[j + 1] != address(0)) {
                    pairAddress = IUniswapV2Factory(factoryAddress).getPair(
                        SWAP_PATH_EARNINGS[i].to[j],
                        SWAP_PATH_EARNINGS[i].to[j + 1]
                    );
                    EarningsOracle.pairAddressToCumlative0[
                        pairAddress
                    ] = IUniswapV2Pair(pairAddress).price0CumulativeLast();
                    EarningsOracle.pairAddressToCumlative1[
                        pairAddress
                    ] = IUniswapV2Pair(pairAddress).price1CumulativeLast();
                    EarningsOracle.timestamp = block.timestamp;
                } else {
                    break;
                }
            }
        }
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 2; j++) {
                if (SWAP_PATH_FEES[i].to[j + 1] != address(0)) {
                    pairAddress = IUniswapV2Factory(factoryAddress).getPair(
                        SWAP_PATH_FEES[i].to[j],
                        SWAP_PATH_FEES[i].to[j + 1]
                    );
                    FeesOracle.pairAddressToCumlative0[
                        pairAddress
                    ] = IUniswapV2Pair(pairAddress).price0CumulativeLast();
                    FeesOracle.pairAddressToCumlative1[
                        pairAddress
                    ] = IUniswapV2Pair(pairAddress).price1CumulativeLast();
                    FeesOracle.timestamp = block.timestamp;
                } else {
                    break;
                }
            }
        }
    }
}
