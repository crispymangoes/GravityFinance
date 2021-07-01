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
}

contract VaultCompGFI is ERC20 {
    IERC20 GFI;
    IGFIFarm Farm;
    constructor(address gfiAddress, address farmAddress) ERC20("GFI-CompShare", "GFI-CS"){
        GFI = IERC20(gfiAddress);
        Farm = IGFIFarm(farmAddress);
    }

    /**
    * @dev called by users to deposit GFI into the pool, will mint them share tokens
    **/
    function deposit(uint amount) public {
        uint farmBalance = Farm.userInfo(address(this)).amount;
        uint gfiPerShare = farmBalance/totalSupply();
        
        require(GFI.transferFrom(msg.sender, address(this), amount));

    }

    /**
    * @dev called by users to burn their share tokens for GFI
    **/
    function withdraw(uint amount) public {

        require(transferFrom(msg.sender, address(this), amount));

        _burn(address(this), amount);
    }

    /**
    * @dev called when users enter/exit the pool, or user manually calls it
    * harvests current rewards, takes profit fee, sends it to a holding contract to burn it, then reinvests GFI
    **/
    function _harvest() internal {
        //if pending rewards is greater then 10 GFI
        Farm.deposit(0);

    }

    function harvest() public {

        _harvest();
        //Transfer small reward to caller
    }

}