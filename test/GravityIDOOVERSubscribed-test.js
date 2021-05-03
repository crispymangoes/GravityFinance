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

describe("GravityIDO after sale functional test OVER SUBSCRIBED", function() {
    before(async function () { 
        [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    
        MockERC20 = await ethers.getContractFactory("MockToken");
        mockWETH = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
        await mockWETH.deployed();  
    
        MockGFI = await ethers.getContractFactory("GravityToken");
        mockGFI = await MockGFI.deploy("Mock Gravity Finance", "MGFI");
        await mockGFI.deployed();
    
        GravityIDO = await ethers.getContractFactory("GravityIDO");
        gravityIDO = await GravityIDO.deploy(mockWETH.address, mockGFI.address, "40000000000000000000000");
        await gravityIDO.deployed();
    
        IOU_ADDRESS = await gravityIDO.getIOUAddress();
    
        IOUToken = await ethers.getContractFactory("IOUToken");
        gravityIOU = await IOUToken.attach(IOU_ADDRESS);

        //Set next block timestamp to be 1 second after IDO starts
        await network.provider.send("evm_setNextBlockTimestamp", [1621404001]);
        await network.provider.send("evm_mine");

        await mockGFI.connect(owner).transfer(gravityIDO.address, "40000000000000000000000");// Transfeer 40,000,000 GFI to IDO
        await mockWETH.connect(addr2).approve(gravityIDO.address, "500000000000000000");
        await mockWETH.connect(addr3).approve(gravityIDO.address, "500000000000000000");
        await mockWETH.connect(addr4).approve(gravityIDO.address, "500000000000000000");

        await gravityIDO.connect(addr2).buyStake("500000000000000000");
        await gravityIDO.connect(addr3).buyStake("500000000000000000");
        await gravityIDO.connect(addr4).buyStake("500000000000000000");

        //Set next block timestamp to be 1 second after IDO ends
        await network.provider.send("evm_setNextBlockTimestamp", [1621490401]);
        await network.provider.send("evm_mine");
    });

    it("claimStake() should accept 0.5 GFI_IDO from 3 users, burn it, and return 13,333 GFI, and 0.166 WETH to each caller", async function() {
        await gravityIOU.connect(addr2).approve(gravityIDO.address, "5000000000000000000");
        await gravityIDO.connect(addr2).claimStake();

        await gravityIOU.connect(addr3).approve(gravityIDO.address, "5000000000000000000");
        await gravityIDO.connect(addr3).claimStake();

        await gravityIOU.connect(addr4).approve(gravityIDO.address, "5000000000000000000");
        await gravityIDO.connect(addr4).claimStake();

        expect(await mockGFI.balanceOf(addr2.address)/1000000000000000).to.be.above(13333333); // > 13,333.333 GFI
        expect(await mockWETH.balanceOf(addr2.address)/1000000000000000).to.be.above(166); // > 0.166 WETH

        expect(await mockGFI.balanceOf(addr3.address)/1000000000000000).to.be.above(13333333); // > 13,333.333 GFI
        expect(await mockWETH.balanceOf(addr3.address)/1000000000000000).to.be.above(166); // > 0.166 WETH

        expect(await mockGFI.balanceOf(addr4.address)/1000000000000000).to.be.above(13333333); // > 13,333.333 GFI
        expect(await mockWETH.balanceOf(addr4.address)/1000000000000000).to.be.above(166); // > 0.166 WETH
    });

    it("withdraw() should callable by owner. 0.5WETH should go to Treasury, and 39,980,000 GFI should Promotion fund", async function() {
        await gravityIDO.connect(owner).withdraw();
        expect(await mockGFI.balanceOf("0x8c7887BA91b359BC574525F05Cc403F51858c2E4")/1000000000000000).to.equal(0); //Check if IOUs were burned
        expect(await mockWETH.balanceOf("0xE471f43De327bF352b5E922FeA92eF6D026B4Af0")/1000000000000000).to.equal(1000); //Check if user recieved correct amount of GFI
    });
});