const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

let MockERC20;
let mockWETH;
let MockGFI;
let mockGFI;
let GravityIDO;
let gravityIDO;
let IOU_ADDRESS;
let IOUToken;
let gravityIOU;

//Test wallet addresses
let owner; // Test contract owner
let addr1; // Test user 1
let addr2; // Test user 2
let addr3; // Test user 3
let addr4; // Test user 4

beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockWETH = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWETH.deployed();  

    MockGFI = await ethers.getContractFactory("GravityToken");
    mockGFI = await MockGFI.deploy("Mock Gravity Finance", "MGFI");
    await mockGFI.deployed();
    /*
    Governance = await ethers.getContractFactory("Governance");
    governance = await Governance.deploy(mockWETH.address, mockGFI.address, 0, true);
    await governance.deployed();
    */
   Locking = await ethers.getContractFactory("Locking");
   locking = await Locking.deploy(mockGFI.address, mockWETH.address, mockWETH.address); //final mockWETH address is just subbing in for the Goverance contract
   await locking.deployed();
   await mockGFI.approve(locking.address, "100000000");
   await locking.addUser(addr1.address, "100000000");
});

describe("Locking Contract functional test", function() {
    it("claimGFI() should revert if called before vesting period is over", async function() {
        await expect(locking.connect(addr1).claimGFI()).to.be.reverted;
    });

    it("claimGFI() should work if vesting period is over", async function() {
        await network.provider.send("evm_setNextBlockTimestamp", [1684031947]);
        await network.provider.send("evm_mine");
        await network.provider.send("evm_mine");
        await locking.connect(addr1).claimGFI();
        let GFIafter = await mockGFI.balanceOf(addr1.address);
        expect(GFIafter).to.equal("100000000");
    });

    it("claimGFI() should revert if caller has no GFI to claim", async function() {
        await expect(locking.connect(addr2).claimGFI()).to.be.reverted;
    });





});
