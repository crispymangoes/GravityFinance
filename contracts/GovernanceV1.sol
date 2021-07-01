// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {iGravityToken} from "./interfaces/iGravityToken.sol";
/**
* @title V1 upgrade for governance contract
* @dev NO LONGER NEEDED while testing, small issue found with claimBTC function this issue has been fixed on the original governance contract
* Leaving this here as a reference 
**/
contract GovernanceV1 is Initializable, OwnableUpgradeable {
    mapping(address => uint256) public feeBalance;
    address public tokenAddress;
    struct FeeLedger {
        uint256 totalFeeCollected_LastClaim;
        uint256 totalSupply_LastClaim;
        uint256 userBalance_LastClaim;
    }
    mapping(address => FeeLedger) public feeLedger;
    uint256 totalFeeCollected;
    iGravityToken GFI;
    IERC20 WETH;
    IERC20 WBTC;

    modifier onlyToken() {
        require(msg.sender == tokenAddress, "Only the token contract can call this function");
        _;
    }

    function initialize(
        address GFI_ADDRESS,
        address WETH_ADDRESS,
        address WBTC_ADDRESS
    ) public initializer {
        __Ownable_init();
        tokenAddress = GFI_ADDRESS;
        GFI = iGravityToken(GFI_ADDRESS);
        WETH = IERC20(WETH_ADDRESS);
        WBTC = IERC20(WBTC_ADDRESS);
    }
    /**
    * @dev internal function called when token contract calls govAuthTransfer or govAuthTransferFrom
    * Will update the recievers fee balance. This will not change the reward they would have got from this fee update
    * rather it updates the fee ledger to reflect the new increased amount of GFI in their wallet
    * @param _address the address of the address recieving GFI tokens
    * @param amount the amount of tokens the address is recieving
    **/
    function _updateFeeReceiver(address _address, uint256 amount)
        internal
        returns (uint256)
    {
        uint256 supply;
        uint256 balance;

        //Pick the greatest supply and the lowest user balance
        uint256 currentBalance = GFI.balanceOf(_address) + amount; //Add the amount they are getting transferred eventhough updateFee will use smaller pre transfer value
        if (currentBalance > feeLedger[_address].userBalance_LastClaim) {
            balance = feeLedger[_address].userBalance_LastClaim;
        } else {
            balance = currentBalance;
        }

        uint256 currentSupply = GFI.totalSupply();
        if (currentSupply < feeLedger[_address].totalSupply_LastClaim) {
            supply = feeLedger[_address].totalSupply_LastClaim;
        } else {
            supply = currentSupply;
        }

        uint256 feeAllocation =
            ((totalFeeCollected -
                feeLedger[_address].totalFeeCollected_LastClaim) * balance) /
                supply;
        feeLedger[_address].totalFeeCollected_LastClaim = totalFeeCollected;
        feeLedger[_address].totalSupply_LastClaim = currentSupply;
        feeLedger[_address].userBalance_LastClaim = currentBalance;
        feeBalance[_address] = feeBalance[_address] + feeAllocation;
        return feeAllocation;
    }
    
    function updateFee(address _address) public returns (uint256) {
        require(GFI.balanceOf(_address) > 0, "_address has no GFI");
        uint256 supply;
        uint256 balance;

        //Pick the greatest supply and the lowest user balance
        uint256 currentBalance = GFI.balanceOf(_address);
        if (currentBalance > feeLedger[_address].userBalance_LastClaim) {
            balance = feeLedger[_address].userBalance_LastClaim;
        } else {
            balance = currentBalance;
        }

        uint256 currentSupply = GFI.totalSupply();
        if (currentSupply < feeLedger[_address].totalSupply_LastClaim) {
            supply = feeLedger[_address].totalSupply_LastClaim;
        } else {
            supply = currentSupply;
        }

        uint256 feeAllocation =
            ((totalFeeCollected -
                feeLedger[_address].totalFeeCollected_LastClaim) * balance) /
                supply;
        feeLedger[_address].totalFeeCollected_LastClaim = totalFeeCollected;
        feeLedger[_address].totalSupply_LastClaim = currentSupply;
        feeLedger[_address].userBalance_LastClaim = currentBalance;
        feeBalance[_address] = feeBalance[_address] + feeAllocation;
        return feeAllocation;
    }

    function claimFee() public returns (uint256) {
        require(GFI.balanceOf(msg.sender) > 0, "User has no GFI");
        uint256 supply;
        uint256 balance;

        //Pick the greatest supply and the lowest user balance
        uint256 currentBalance = GFI.balanceOf(msg.sender);
        if (currentBalance > feeLedger[msg.sender].userBalance_LastClaim) {
            balance = feeLedger[msg.sender].userBalance_LastClaim;
        } else {
            balance = currentBalance;
        }

        uint256 currentSupply = GFI.totalSupply();
        if (currentSupply < feeLedger[msg.sender].totalSupply_LastClaim) {
            supply = feeLedger[msg.sender].totalSupply_LastClaim;
        } else {
            supply = currentSupply;
        }

        uint256 feeAllocation =
            ((totalFeeCollected -
                feeLedger[msg.sender].totalFeeCollected_LastClaim) * balance) /
                supply;
        feeLedger[msg.sender].totalFeeCollected_LastClaim = totalFeeCollected;
        feeLedger[msg.sender].totalSupply_LastClaim = currentSupply;
        feeLedger[msg.sender].userBalance_LastClaim = currentBalance;
        //Add any extra fees they need to collect
        feeAllocation = feeAllocation + feeBalance[msg.sender];
        feeBalance[msg.sender] = 0;
        require(WETH.transfer(msg.sender, feeAllocation),"Failed to delegate wETH to caller");
        return feeAllocation;
    }

    function delegateFee(address reciever) public returns (uint256) {
        require(GFI.balanceOf(msg.sender) > 0, "User has no GFI");
        uint256 supply;
        uint256 balance;

        //Pick the greatest supply and the lowest user balance
        uint256 currentBalance = GFI.balanceOf(msg.sender);
        if (currentBalance > feeLedger[msg.sender].userBalance_LastClaim) {
            balance = feeLedger[msg.sender].userBalance_LastClaim;
        } else {
            balance = currentBalance;
        }

        uint256 currentSupply = GFI.totalSupply();
        if (currentSupply < feeLedger[msg.sender].totalSupply_LastClaim) {
            supply = feeLedger[msg.sender].totalSupply_LastClaim;
        } else {
            supply = currentSupply;
        }

        uint256 feeAllocation =
            ((totalFeeCollected -
                feeLedger[msg.sender].totalFeeCollected_LastClaim) * balance) /
                supply;
        feeLedger[msg.sender].totalFeeCollected_LastClaim = totalFeeCollected;
        feeLedger[msg.sender].totalSupply_LastClaim = currentSupply;
        feeLedger[msg.sender].userBalance_LastClaim = currentBalance;
        //Add any extra fees they need to collect
        feeAllocation = feeAllocation + feeBalance[msg.sender];
        feeBalance[msg.sender] = 0;
        require(WETH.transfer(reciever, feeAllocation), "Failed to delegate wETH to reciever");
        return feeAllocation;
    }

    function withdrawFee() external {
        uint256 feeAllocation = feeBalance[msg.sender];
        feeBalance[msg.sender] = 0;
        require(WETH.transfer(msg.sender, feeAllocation), "Failed to delegate wETH to caller");
    }

    function govAuthTransfer(
        address caller,
        address to,
        uint256 amount
    ) external onlyToken returns (bool) {
        require(GFI.balanceOf(caller) >= amount, "GOVERNANCE: Amount exceedes balance!");
        updateFee(caller);
        _updateFeeReceiver(to, amount);
        return true;
    }

    function govAuthTransferFrom(
        address caller,
        address from,
        address to,
        uint256 amount
    ) external onlyToken returns (bool) {
        require(GFI.allowance(from, caller) >= amount, "GOVERNANCE: Amount exceedes allowance!");
        require(GFI.balanceOf(from) >= amount, "GOVERNANCE: Amount exceedes balance!");
        updateFee(from);
        _updateFeeReceiver(to, amount);
        return true;
    }

    function depositFee(uint256 amountWETH, uint256 amountWBTC) external {
        require(
            WETH.transferFrom(msg.sender, address(this), amountWETH),
            "Failed to transfer wETH into contract!"
        );
        require(
            WBTC.transferFrom(msg.sender, address(this), amountWBTC),
            "Failed to transfer wBTC into contract!"
        );
        totalFeeCollected = totalFeeCollected + amountWETH;
    }

    function claimBTC(uint256 amount) external {
        require(
            amount > 10**18,
            "Amount too small, must be greater than 1 GFI token!"
        );
        require(
            GFI.transferFrom(msg.sender, address(this), amount),
            "Failed to transfer GFI to governance contract!"
        );
        uint256 WBTCowed =
            (amount * WBTC.balanceOf(address(this))) / GFI.totalSupply();
        require(GFI.burn(amount), "Failed to burn GFI!");
        require(
            WBTC.transfer(msg.sender, WBTCowed),
            "Failed to transfer wBTC to caller!"
        );
    }
}
