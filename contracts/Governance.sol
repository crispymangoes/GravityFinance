// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgradeable/contracts/ somethin Initializer.sol";

contract Governance is Initializer, Ownable{

    struct FeeLedger {
        uint totalFeeCollected_LastClaim,
        uint totalSupply_LastClaim,
        uint userBalance_LastClaim

    }
    mapping(address => FeeLedger) public feeLedger;
    uint totalFeeCollected;
    IERC20 GFI;
    IERC20 WETH;

    Initializer() {
        ....
    }

    function claimFee() external returns(uint){
        uint supply;
        uint balance;

        //Pick the greatest supply and the lowest user balance
        uint currentBalance = GFI.balanceOf(msg.sender);
        if (currentBalance > feeLedger[msg.sender].userBalance_LastClaim){
            balance = feeLedger[msg.sender].userBalance_LastClaim)
        }
        else {
            balance = currentBalance;
        }

        uint currentSupply = GFI.totalSupply();
        if (currentSupply < feeLedger[msg.sender].totalSupply_LastClaim){
            supply = feeLedger[msg.sender].totalSupply_LastClaim;
        }
        else {
            supply = currentSupply;
        }

        uint feeAllocation = (totalFeeCollected - feeLedger[msg.sender].totalFeeCollected_LastClaim) * balance/supply;
        feeLedger[msg.sender].totalFeeCollected_LastClaim = totalFeeCollected;
        feeLedger[msg.sender].totalSupply_LastClaim = currentSupply;
        feeLedger[msg.sender].userBalance_LastClaim = currentBalance;
        requre(WETH.transferFrom(address(this), msg.sender, feeAllocation));
        return feeAllocation;
    }
}