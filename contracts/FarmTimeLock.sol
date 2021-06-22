// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IFarm.sol";

contract FarmTimeLock is Ownable {

    uint public lockLength;
    uint public graceLength; //Amount of time owner has to call the function before it expires

    uint public changeTimeLock_timestamp;
    uint public changeTimeLock_lockInSec;
    mapping(address => uint) public transferOwnershipFromLock_timestamp;
    mapping(address => address) public transferOwnershipFromLock_newOwner;
    mapping(address => uint) public callWithdrawRewards_timestamp;
    mapping(address => uint) public callWithdrawRewards_amount; //The variable you want to pass into withdrawRewards function call
    uint public withdrawERC20_timestamp;
    address public withdrawERC20_token;
    address public withdrawERC20_wallet;

    /**
    * @dev emitted when proposal to change lock period is made
    * @param valid the timestamp when the proposal will become valid
    * @param newPeriod the new lock period in seconds
    **/
    event lockPeriodChanged(uint valid, uint newPeriod);

    /**
    * @dev emitted when proposal to change farm owner is made
    * @param valid the timestamp when the proposal will become valid
    * @param farm the address of the farm
    * @param newOwner the address of the new owner
    **/
    event transferOwnershipCalled(uint valid, address farm, address newOwner);
    
    /**
    * @dev emitted when proposal to call withdraw rewards is made
    * @param valid the timestamp when the proposal will become valid
    * @param farm the address of the farm
    * @param amount the amount of tokens to withdraw with 10**18 decimals
    **/
    event withdrawRewards(uint valid, address farm, uint amount);
    
    /**
    * @dev emitted when proposal to withdraw ERC20 tokens from this contract is made
    * @param token the token address of the token to withdraw
    * @param to the address of the wallet to send the tokens to
    **/
    event withdraw(uint valid, address token, address to);

    constructor(){
        lockLength = 604800; // 1 week by default
        graceLength = 86400; //owner has 1 day to call the function once it is valid
    }

    /**
    * @dev allows owner to change the lock period after the lock period is up, and set it anywhere from 1 day to 30 days
    * @param lockInSec the new lock period time in seconds
    **/
    function changeTimeLock(uint lockInSec) external onlyOwner{
        uint validStart = changeTimeLock_timestamp + lockLength;
        uint validEnd = changeTimeLock_timestamp + lockLength + graceLength;

        if (block.timestamp > validStart && block.timestamp < validEnd){//If request is now valid fulfill it
            changeTimeLock_timestamp = 0; //reset the timestamp
            lockLength = changeTimeLock_lockInSec;
        }

        else{ //Call is not valid so reset timestamp and capture input
            if(block.timestamp > validEnd){//Only make a new timestamp if the current one is expired
                require(lockInSec > 86400, "Locking period must be greater than 1 day!");
                require(lockInSec < 2592000, "Locking period can not be greater than a month!");
                changeTimeLock_timestamp = block.timestamp;
                changeTimeLock_lockInSec = lockInSec;
                emit lockPeriodChanged(validStart, lockInSec);
            }
        }
    }

    /**
    * @dev allows owner to call the transferOwnership function in any farm (that has it's owner set as this address) after the time lock period is up, and before the call expires
    * @param farm the address of the farm to call withdrawRewards on
    * @param newOwner the address of the new owner of the farm contract
    **/
    function transferOwnershipFromLock(address farm, address newOwner) external onlyOwner{
        uint validStart = transferOwnershipFromLock_timestamp[farm] + lockLength;
        uint validEnd = transferOwnershipFromLock_timestamp[farm] + lockLength + graceLength;

        if (block.timestamp > validStart && block.timestamp < validEnd){//If request is now valid fulfill it
            transferOwnershipFromLock_timestamp[farm] = 0; //reset the timestamp
            IFarm(farm).transferOwnership(transferOwnershipFromLock_newOwner[farm]);
        }

        else{ //Call is not valid so reset timestamp and capture input
            if(block.timestamp > validEnd){//Only make a new timestamp if the current one is expired
                transferOwnershipFromLock_timestamp[farm] = block.timestamp;
                transferOwnershipFromLock_newOwner[farm] = newOwner;
                emit transferOwnershipCalled(validStart, farm, newOwner);
            }
        }
    }

    /**
    * @dev allows owner to call the withdrawRewards function in any farm (that has it's owner set as this address) after the time lock period is up, and before the call expires
    * @param farm the address of the farm to call withdrawRewards on
    * @param amount the amount of tokens to withdraw from the pool
    **/
    function callWithdrawRewards(address farm, uint amount) external onlyOwner{
        require(IFarm(farm).owner() == address(this), "Time lock contract does not own farm contract!");
        uint validStart = callWithdrawRewards_timestamp[farm] + lockLength;
        uint validEnd = callWithdrawRewards_timestamp[farm] + lockLength + graceLength;

        if (block.timestamp > validStart && block.timestamp < validEnd){//If request is now valid fulfill it
            callWithdrawRewards_timestamp[farm] = 0; //reset the timestamp
            IFarm(farm).withdrawRewards(callWithdrawRewards_amount[farm]);
        }

        else{ //Call is not valid so reset timestamp and capture input
            if(block.timestamp > validEnd){//Only make a new timestamp if the current one is expired
                callWithdrawRewards_timestamp[farm] = block.timestamp;
                callWithdrawRewards_amount[farm] = amount;
                emit withdrawRewards(validStart, farm, amount);
            }
        }
    }

    /**
    * @dev allows owner to withdraw any ERC20 token from THIS contract, after waiting a week.
    * note, token address, and recieving wallet address are publically visible for the week up until the call is valid
    * @param token the address of the ERC20 token you want to withdraw from this contract
    * @param wallet the address of the reciever of withdrawn tokens
    **/
    function withdrawERC20(address token, address wallet) external onlyOwner{
        uint validStart = withdrawERC20_timestamp + lockLength;
        uint validEnd = withdrawERC20_timestamp + lockLength + graceLength;

        if (block.timestamp > validStart && block.timestamp < validEnd){//If request is now valid fulfill it
            withdrawERC20_timestamp = 0; //reset the timestamp
            IERC20 Token = IERC20(withdrawERC20_token);
            Token.transfer(withdrawERC20_wallet, Token.balanceOf(address(this)));
        }

        else{ //Call is not valid so reset timestamp and capture input
            if(block.timestamp > validEnd){//Only make a new timestamp if the current one is expired
                withdrawERC20_timestamp = block.timestamp;
                withdrawERC20_wallet = wallet;
                withdrawERC20_token = token;
                emit withdraw(validStart, token, wallet);
            }
        }
    }
}