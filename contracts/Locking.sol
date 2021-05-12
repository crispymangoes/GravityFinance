// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Locking is Ownable {
    mapping(address => uint256) public balance;
    mapping(address => uint256) public withdrawableFee;
    address[] public users;
    uint256 public userCount;
    uint256 public totalBalance;
    uint256 public lastFeeUpdate; // Timestamp for when updateWithdrawableFee() was last called
    IERC20 GFI;
    IERC20 WETH;
    iGovernance Governor;
    address public GOVERANCE_ADDRESS;
    uint256 public LockStart;
    uint256 public LockEnd;
    bool public stopFeeCollection;

    constructor(
        address GFI_ADDRESS,
        address WETH_ADDRESS,
        address _GOVERNANCE_ADDRESS
    ) {
        GFI = IERC20(GFI_ADDRESS);
        WETH = IERC20(WETH_ADDRESS);
        GOVERANCE_ADDRESS = _GOVERNANCE_ADDRESS;
        Governor = iGovernance(GOVERANCE_ADDRESS);
        LockStart = block.timestamp;
        LockEnd = LockStart + (60*60*24*365); //One year from contract deployment
    }

    function setGovenorAddress(address _address) external onlyOwner {
        GOVERANCE_ADDRESS = _address;
        Governor = iGovernance(GOVERANCE_ADDRESS);
    }

    /** @dev Allows owner to add new allowances for users
     * Address must not have an existing balance
     */
    function addUser(address _address, uint256 bal) external onlyOwner {
        require(balance[_address] == 0, "User is already in the contract!");
        require(
            GFI.transferFrom(msg.sender, address(this), bal),
            "GFI transferFrom failed!"
        );
        balance[_address] = bal;
        users.push(_address);
        userCount++;
        totalBalance = totalBalance + bal;
    }

    function updateWithdrawableFee() external {
        uint256 collectedFee = Governor.claimFee();
        uint256 callersFee = collectedFee / 100;
        collectedFee = collectedFee - callersFee;
        uint256 userShare;
        for (uint256 i = 0; i < userCount; i++) {
            userShare = (collectedFee * balance[users[i]]) / totalBalance;
            //Remove last digit of userShare
            userShare = userShare / 10;
            userShare = userShare * 10;
            withdrawableFee[users[i]] = withdrawableFee[users[i]] + userShare;
        }
        lastFeeUpdate = block.timestamp;
        require(
            WETH.transferFrom(address(this), msg.sender, callersFee),
            "Failed to transfer callers fee to caller!"
        );
    }

    function collectFee() external {
        require(stopFeeCollection, "Fee distibution has been turned off!");
        require(withdrawableFee[msg.sender] > 0, "Caller has no fee to claim!");
        uint256 tmpBal = withdrawableFee[msg.sender];
        withdrawableFee[msg.sender] = 0;
        require(WETH.transferFrom(address(this), msg.sender, tmpBal));
    }

    function claimGFI() external {
        require(balance[msg.sender] > 0, "Caller has no GFI to claim!");
        require(block.timestamp > LockEnd, "GFI tokens are not fully vested!");
        require(
            GFI.transferFrom(address(this), msg.sender, balance[msg.sender]),
            "Failed to transfer GFI to caller!"
        );
    }

    function withdrawAll() external onlyOwner {
        require(block.timestamp > LockEnd, "Locking Period is not over yet!");
        require(WETH.transferFrom(address(this), msg.sender, WETH.balanceOf(address(this))), "Failed to transfer WETH to Owner!");
    }
}

interface iGovernance {
    /**
     * Assume claimFee uses msg.sender, and returns the amount of WETH sent to the caller
     */
    function claimFee() external returns (uint256);
}
