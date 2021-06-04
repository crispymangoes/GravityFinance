// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


interface iLogistics {
    /**
     * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
     */
    function createSwapPaths(address factoryAddress, address WETH_ADDRESS, address WBTC_ADDRESS, address t0, address t1) external;

    function updateOracles(address factoryAddress) external;
}