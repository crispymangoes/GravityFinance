// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


interface IPriceOracle {
    /**
     * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
     */
    function getPrice(address pairAddress) external returns (uint price0Average, uint price1Average, uint timeTillValid);

    function calculateMinAmount(address from, uint256 slippage, uint256 amount, address pairAddress) external returns (uint minAmount, uint timeTillValid);
}