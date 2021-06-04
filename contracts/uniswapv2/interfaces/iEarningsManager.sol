// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;


interface iEarningsManager {
    /**
     * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
     */
    function manageEarnings(address caller) external;
    function manageFees() external;
}