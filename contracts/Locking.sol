// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Locking is Ownable {

    struct quarterlyLedger {
        bool Q1_CLAIM;
        bool Q2_CLAIM;
        bool Q3_CLAIM;
        bool Q4_CLAIM;
        uint CLAIM_PER_Q;
    }
    mapping(address => quarterlyLedger) public QLedger;
    mapping(address => uint) public balance;
    mapping(address => uint) public withdrawableFee;
    address[] public users;
    uint public userCount;
    uint public totalBalance;
    uint public lastFeeUpdate; // Timestamp for when updateWithdrawableFee() was last called
    IERC20 GFI;
    IERC20 WETH;
    iGovernance Governor;
    uint public LockStart;
    uint public LockEnd;
    bool collectFeeORVestOverTime = true; // If the fee logic changes signifigantly, then changing this bool makes it so fees are no longer collectable, but users can withdraw a portion of their stake every Q
    constructor(address GFI_ADDRESS, address WETH_ADDRESS) {
        GFI = IERC20(GFI_ADDRESS);
        WETH = IERC20(WETH_ADDRESS);
        LockStart = block.timestamp;
    }

    function setBool(bool _bool) external onlyOwner{
        collectFeeORVestOverTime = _bool;
    }
    /** @dev Allows owner to add new allowances for users
    * Address must not have an existing balance
     */
    function addUser(address _address, uint bal) external onlyOwner {
        require(balance[_address] == 0, "User is already in the contract!");
        require(GFI.transferFrom(msg.sender, address(this), bal), "GFI transferFrom failed!");
        balance[_address] = bal;
        users.push(_address);
        userCount++;
        totalBalance = totalBalance + bal;

        QLedger[_address] = quarterlyLedger(
            {
            Q1_CLAIM: false,
            Q2_CLAIM: false,
            Q3_CLAIM: false,
            Q4_CLAIM: false,
            CLAIM_PER_Q: bal/4
            }
        );
    }

    function updateWithdrawableFee() external {
        require(collectFeeORVestOverTime, "Contract fee logic does not work with Governance contract fee logic!");
        uint collectedFee = Governor.claimFee();
        uint callersFee = collectedFee / 100;
        collectedFee = collectedFee - callersFee;
        uint userShare;
        for (uint i=0; i<userCount; i++){
            userShare = collectedFee * balance[users[i]]/totalBalance;
            //Remove last digit of userShare
            userShare = userShare / 10;
            userShare = userShare * 10;
            withdrawableFee[users[i]] = withdrawableFee[users[i]] + userShare;
        }
        lastFeeUpdate = block.timestamp;
        require(WETH.transferFrom(address(this), msg.sender, callersFee), "Failed to transfer callers fee to caller!");
    }

    function collectFee() external {
        require(withdrawableFee[msg.sender] > 0, "Caller has no fee to claim!");
        uint tmpBal = withdrawableFee[msg.sender];
        withdrawableFee[msg.sender] = 0;
        require(WETH.transferFrom(address(this), msg.sender, tmpBal));
    }

    function claimGFI()external {
        if (collectFeeORVestOverTime){
            require(balance[msg.sender] > 0, "Caller has no GFI to claim!");
            require(block.timestamp > LockEnd, "GFI tokens are not fully vested!");
            require(GFI.transferFrom(address(this), msg.sender, balance[msg.sender]), "Failed to transfer GFI to caller!");
        }
        else {
            require(balance[msg.sender] > 0, "Caller has no GFI to claim!");
            if (block.timestamp > (LockStart + 7776000)) { //3 months after contract creation
                if(!QLedger[msg.sender].Q1_CLAIM){
                    QLedger[msg.sender].Q1_CLAIM = true;
                    balance[msg.sender] = balance[msg.sender] - QLedger[msg.sender].CLAIM_PER_Q;
                    totalBalance = totalBalance - QLedger[msg.sender].CLAIM_PER_Q;
                    require(GFI.transferFrom(address(this), msg.sender, QLedger[msg.sender].CLAIM_PER_Q));
                }
            }

            if (block.timestamp > (LockStart + 15552000)) { //3 months after contract creation
                if(!QLedger[msg.sender].Q2_CLAIM){
                    QLedger[msg.sender].Q2_CLAIM = true;
                    balance[msg.sender] = balance[msg.sender] - QLedger[msg.sender].CLAIM_PER_Q;
                    totalBalance = totalBalance - QLedger[msg.sender].CLAIM_PER_Q;
                    require(GFI.transferFrom(address(this), msg.sender, QLedger[msg.sender].CLAIM_PER_Q));
                }
            }

            if (block.timestamp > (LockStart + 23328000)) { //9 months after contract creation
                if(!QLedger[msg.sender].Q3_CLAIM){
                    QLedger[msg.sender].Q3_CLAIM = true;
                    balance[msg.sender] = balance[msg.sender] - QLedger[msg.sender].CLAIM_PER_Q;
                    totalBalance = totalBalance - QLedger[msg.sender].CLAIM_PER_Q;
                    require(GFI.transferFrom(address(this), msg.sender, QLedger[msg.sender].CLAIM_PER_Q));
                }
            }

            if (block.timestamp > (LockStart + 31104000)) { //12 months after contract creation
                if(!QLedger[msg.sender].Q4_CLAIM){
                    QLedger[msg.sender].Q4_CLAIM = true;
                    uint tmpBal = balance[msg.sender];
                    balance[msg.sender] = 0;
                    totalBalance = totalBalance - tmpBal;
                    require(GFI.transferFrom(address(this), msg.sender, tmpBal));
                }
            }
        }
    }
}

interface iGovernance{
    /**
    * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
    */
    function claimFee() external returns(uint);
}