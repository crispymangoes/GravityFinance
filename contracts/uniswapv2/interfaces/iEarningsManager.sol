// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


interface iEarningsManager {
    /**
     * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
     */
    function manageEarnings() external;
    function manageFees() external;
    function changeSlippage(uint _slippage) external;
    function checkPrice() external returns(uint timeTillValid);
    function updateSwapPath() external;
    function checkPricing() external returns(bool allPricesValid, uint maxTime);
}