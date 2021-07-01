// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

struct UserInfo {
        uint256 amount;     // LP tokens provided.
        uint256 rewardDebt; // Reward debt.
    }

interface IGFIFarm {
    function userInfo(address user) external view returns (UserInfo memory);
    function deposit(uint256 _amount) external;
    function pendingReward(address _user) external view returns (uint256);
}

contract VaultCompGFI is ERC20 {
    IERC20 GFI;
    IGFIFarm Farm;
    uint public harvestThreshold; //make this changeable by owner, but make it so that it needs to fall in a range
    constructor(address gfiAddress, address farmAddress) ERC20("GFI-CompShare", "GFI-CS"){
        GFI = IERC20(gfiAddress);
        Farm = IGFIFarm(farmAddress);
    }

    /**
    * @dev called by users to deposit GFI into the pool, will mint them share tokens
    **/
    function deposit(uint amount) public {
        _harvest();
        uint farmBalance = Farm.userInfo(address(this)).amount;
        uint gfiPerShare = farmBalance/totalSupply();
        
        require(GFI.transferFrom(msg.sender, address(this), amount));

    }

    /**
    * @dev called by users to burn their share tokens for GFI
    **/
    function withdraw(uint amount) public {
        _harvest();
        uint farmBalance = Farm.userInfo(address(this)).amount;
        uint gfiPerShare = farmBalance/totalSupply();
        require(transferFrom(msg.sender, address(this), amount));
        _burn(address(this), amount);
    }

    /**
    * @dev called when users enter/exit the pool, or user manually calls it
    * harvests current rewards, takes profit fee, sends it to a holding contract to burn it, then reinvests GFI
    **/
    function _harvest() internal {
        //if pending rewards is greater then 10 GFI
        if(Farm.pendingReward(address(this)) > harvestThreshold){
        Farm.deposit(0);
        //send 4%(make it adjustable) to a holding contract to be burned
        //calculate callers fee(make the percentage adjustable so we can control how often this is called)
        //Reinvest the rest
        }

    }

    function harvest() public {

        _harvest();
        //Transfer small reward to caller
    }

}