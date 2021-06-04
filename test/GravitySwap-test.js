const { expect } = require("chai");
const { ethers, network, upgrades } = require("hardhat");
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
let addr5;

beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockWETH = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWETH.deployed();  

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockWBTC = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWBTC.deployed();

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockUSDC = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockUSDC.deployed();

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockDAI = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockDAI.deployed();

    MockGFI = await ethers.getContractFactory("GravityToken");
    mockGFI = await MockGFI.deploy("Mock Gravity Finance", "MGFI");
    await mockGFI.deployed();

    Governance = await ethers.getContractFactory("Governance");
    governance = await upgrades.deployProxy(Governance, [mockGFI.address, mockWETH.address, mockWBTC.address], {initializer: 'initialize'});
    await governance.deployed();

   SwapEX = await ethers.getContractFactory("UniswapV2Factory");
   swapEX = await SwapEX.deploy(mockGFI.address, mockWETH.address, mockWETH.address, 1622530800, 2592000); //final mockWETH address is just subbing in for the Goverance contract
   await vesting.deployed();
   await mockGFI.approve(vesting.address, "100000000");
   await vesting.addUser(addr1.address, "100000000");
   await mockGFI.approve(vesting.address, "200000000");
   await vesting.addUser(addr3.address, "200000000");

   await mockGFI.approve(vesting.address, "5000000000000000000000000");
   await vesting.addUser(addr4.address, "5000000000000000000000000");
   await mockGFI.approve(vesting.address, "195000000000000000000000000");
   await vesting.addUser(addr2.address, "195000000000000000000000000");

   //Just to remove wETH bal for addr4
   await mockWETH.connect(addr4).transfer(owner.address, "10000000000000000000");

   await vesting.setGovenorAddress(governance.address);
   await mockWETH.connect(addr2).approve(governance.address, "10000000000000000000");
   await vesting.setFeeCollectionBool(true);
   await governance.updateFee(vesting.address);
   await governance.connect(addr2).depositFee("10000000000000000000", "0");
});
