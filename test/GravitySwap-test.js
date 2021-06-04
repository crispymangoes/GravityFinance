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

    MockWMATIC = await ethers.getContractFactory("GravityToken");
    mockWMATIC = await MockWMATIC.deploy("Mock Gravity Finance", "MGFI");
    await mockWMATIC.deployed();

    Governance = await ethers.getContractFactory("Governance");
    governance = await upgrades.deployProxy(Governance, [mockGFI.address, mockWETH.address, mockWBTC.address], { initializer: 'initialize' });
    await governance.deployed();
    
    SwapFactory = await ethers.getContractFactory("UniswapV2Factory");
    swapFactory = await SwapFactory.deploy(owner.address, governance.address, mockWETH.address, mockWBTC.address);
    await swapFactory.deployed();

    SwapRouter = await ethers.getContractFactory("UniswapV2Router02");
    swapRouter = await SwapRouter.deploy(swapFactory.address, mockWMATIC.address);
    await swapRouter.deployed();

});

describe("Swap Exchange Contracts functional test", function () {
    it("Should allow me to create an LP pool", async function () {
        
        //await expect(swapFactory.createPair(mockWETH.address, mockWBTC.address)).to.emit(swapFactory, 'PairCreated').withArgs(mockWETH.address, mockWBTC.address, "0x50B2091E99e9E78fD6b9fEf54265490ADBa27B19", 1);
        //let pairAddress = await swapRouter.pairFor(swapFactory.address, mockWETH.address, mockWBTC.address);
        //console.log(pairAddress);
        //let Pair = await ethers.getContractFactory("UniswapV2Pair");
        //let pair = await Pair.attach(pairAddress);
        //console.log((await pair.getReserves()).toString());
        await mockWETH.approve(swapRouter.address, "100000000000000000000");
        await mockWBTC.approve(swapRouter.address, "100000000000000000000");
        await swapRouter.addLiquidity(mockWETH.address, mockWBTC.address, "1000000000000000000", "1000000000000000000", "900000000000000000", "900000000000000000", addr1.address, 1654341846);
        /*await expect(factory.createPair(...tokens))
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, bigNumberify(1))*/
    });


});