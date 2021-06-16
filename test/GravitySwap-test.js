const { expect } = require("chai");
const { ethers, network, upgrades, getBlockNumber } = require("hardhat");
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

let WETH;
let WBTC;
let GFI;
let USDC;
let DAI;
let WMATIC;

before(async function () {
    [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockWETH = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWETH.deployed();
    WETH = mockWETH.address;

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockWBTC = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWBTC.deployed();
    WBTC = mockWBTC.address;

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockUSDC = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockUSDC.deployed();
    USDC = mockUSDC.address;

    MockERC20 = await ethers.getContractFactory("MockToken");
    mockDAI = await MockERC20.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockDAI.deployed();
    DAI = mockDAI.address;

    MockGFI = await ethers.getContractFactory("GravityToken");
    mockGFI = await MockGFI.deploy("Mock Gravity Finance", "MGFI");
    await mockGFI.deployed();
    GFI = mockGFI.address;

    MockWMATIC = await ethers.getContractFactory("MockToken");
    mockWMATIC = await MockWMATIC.deploy(addr1.address, addr2.address, addr3.address, addr4.address);
    await mockWMATIC.deployed();
    WMATIC = mockWMATIC.address;

    Governance = await ethers.getContractFactory("Governance");
    governance = await upgrades.deployProxy(Governance, [mockGFI.address, mockWETH.address, mockWBTC.address], { initializer: 'initialize' });
    await governance.deployed();
    await mockGFI.setGovernanceAddress(governance.address);
    await mockGFI.changeGovernanceForwarding(true);
    
    PathOracle = await ethers.getContractFactory("PathOracle");
    pathOracle = await PathOracle.deploy([mockWETH.address, mockWBTC.address, mockGFI.address, mockUSDC.address, mockDAI.address], 5, mockWETH.address, mockWBTC.address);
    await pathOracle.deployed();
    await pathOracle.alterPath(WETH, WBTC);

    PriceOracle = await ethers.getContractFactory("PriceOracle");
    priceOracle = await PriceOracle.deploy(300, 600);
    await priceOracle.deployed();

    SwapFactory = await ethers.getContractFactory("UniswapV2Factory");
    swapFactory = await SwapFactory.deploy(owner.address);
    await swapFactory.deployed();

    await pathOracle.setFactory(swapFactory.address);

    SwapRouter = await ethers.getContractFactory("UniswapV2Router02");
    swapRouter = await SwapRouter.deploy(swapFactory.address, mockWMATIC.address);
    await swapRouter.deployed();

    FeeManager = await ethers.getContractFactory("FeeManager");
    feeManager = await FeeManager.deploy(swapFactory.address);
    await feeManager.deployed;

    EarningsManager = await ethers.getContractFactory("EarningsManager");
    earningsManager = await EarningsManager.deploy(swapFactory.address);
    await earningsManager.deployed;

    await swapFactory.setRouter(swapRouter.address);

    await swapFactory.setRouter(swapRouter.address);
    await swapFactory.setGovernor(governance.address);
    await swapFactory.setWETH(mockWETH.address);
    await swapFactory.setWBTC(mockWBTC.address);
    await swapFactory.setGFI(mockGFI.address);
    await swapFactory.setPathOracle(pathOracle.address);
    await swapFactory.setPriceOracle(priceOracle.address);
    await swapFactory.setEarningsManager(earningsManager.address);
    await swapFactory.setFeeManager(feeManager.address);
    await swapFactory.setDustPan(addr5.address);
    await swapFactory.setPaused(false);
    await swapFactory.setSlippage(95);

});

describe("Swap Exchange Contracts functional test", function () {
    it("Should allow caller to create an LP pool", async function () {
        
        //await expect(swapFactory.createPair(mockWETH.address, mockWBTC.address)).to.emit(swapFactory, 'PairCreated').withArgs(mockWETH.address, mockWBTC.address, "0x50B2091E99e9E78fD6b9fEf54265490ADBa27B19", 1);
        //let pairAddress = await swapRouter.pairFor(swapFactory.address, mockWETH.address, mockWBTC.address);
        //console.log(pairAddress);
        //let Pair = await ethers.getContractFactory("UniswapV2Pair");
        //let pair = await Pair.attach(pairAddress);
        //console.log((await pair.getReserves()).toString());
        //Create wETH wBTC pair
        let pairAddress;
        await mockWETH.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr1).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr1).addLiquidity(mockWETH.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "990000000000000000000", "99000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockWETH.address, mockWBTC.address);
        console.log("Created wETH/wBTC at: ", pairAddress);
        //let Pair = await ethers.getContractFactory("UniswapV2Pair");
        //let pair = await Pair.attach(pairAddress);
        //console.log((await pair.balanceOf(addr1.address)).toString());

        //Create wBTC USDC pair
        await mockUSDC.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr1).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr1).addLiquidity(mockUSDC.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "990000000000000000000", "99000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockUSDC.address, mockWBTC.address);
        console.log("Created USDC/wBTC at: ", pairAddress);

        //Create wBTC GFI pair
        await mockGFI.transfer(addr1.address, "1000000000000000000000");
        await mockGFI.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr1).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr1).addLiquidity(mockGFI.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "990000000000000000000", "99000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockGFI.address, mockWBTC.address);
        console.log("Created  GFI/wBTC at: ", pairAddress);

        /*await expect(factory.createPair(...tokens))
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, bigNumberify(1))*/
    });

    it("Should allow caller to swap wBTC for wETH", async function () {
        let pairAddress;
        pairAddress = await swapFactory.getPair(mockWETH.address, mockWBTC.address);
        let Pair = await ethers.getContractFactory("UniswapV2Pair");
        let pair = await Pair.attach(pairAddress);
        let holderPair = await pair.HOLDING_ADDRESS();
        await mockWBTC.connect(addr2).approve(swapRouter.address, "1000000000000000000000");
        let path = [mockWBTC.address, mockWETH.address];
        console.log("Swap wBTC for wETH");
        let kBefore = await mockWETH.balanceOf(pairAddress) * await mockWBTC.balanceOf(pairAddress);
        console.log("K before swap: ", kBefore);
        await swapRouter.connect(addr2).swapExactTokensForTokens("1000000000000000000", "9000000000000000000", path, addr2.address, 1654341846);
        let kAfter = await mockWETH.balanceOf(pairAddress) * await mockWBTC.balanceOf(pairAddress);
        console.log("K after swap: ", kAfter);
        console.log("Earnings Manager for pair: ", holderPair);
        console.log("WBTC Balance of Earnings Manager: ", (await mockWBTC.balanceOf(holderPair)).toString());
        console.log("WETH Balance of Earnings Manager: ", (await mockWETH.balanceOf(holderPair)).toString());
        
    });

    it("Should allow caller to swap wETH for USDC", async function () {
        let pairAddress;
        pairAddress = await swapFactory.getPair(mockWETH.address, mockWBTC.address);
        let pairAddress1;
        pairAddress1 = await swapFactory.getPair(mockUSDC.address, mockWBTC.address);
        let Pair = await ethers.getContractFactory("UniswapV2Pair");
        let pair = await Pair.attach(pairAddress);
        let holderPair = await pair.HOLDING_ADDRESS();
        await mockWETH.connect(addr2).approve(swapRouter.address, "1000000000000000000000");
        let path = [mockWETH.address, mockWBTC.address, mockUSDC.address];
        console.log("Swap wETH for USDC");

        let kBefore_wETH_wBTC = await mockWETH.balanceOf(pairAddress) * await mockWBTC.balanceOf(pairAddress);
        console.log("wETH/wBTC K before swap: ", kBefore_wETH_wBTC);
        let kBefore_USDC_wBTC = await mockUSDC.balanceOf(pairAddress1) * await mockWBTC.balanceOf(pairAddress1);
        console.log("USDC/wBTC K before swap: ", kBefore_USDC_wBTC);
        await swapRouter.connect(addr2).swapExactTokensForTokens("1000000000000000000", "900000000000000000", path, addr2.address, 1654341846);
        let kAfter_wETH_wBTC = await mockWETH.balanceOf(pairAddress) * await mockWBTC.balanceOf(pairAddress);
        console.log("wETH/wBTC K after swap: ", kAfter_wETH_wBTC);
        let kAfter_USDC_wBTC = await mockUSDC.balanceOf(pairAddress1) * await mockWBTC.balanceOf(pairAddress1);
        console.log("USDC/wBTC K after swap: ", kAfter_USDC_wBTC);

        console.log("K value increased by: ", ( ((kAfter_wETH_wBTC/kBefore_wETH_wBTC) - 1)*100 ).toFixed(8) );

        console.log("Earnings Manager for pair: ", holderPair);
        console.log("WBTC Balance of Earnings Manager: ", (await mockWBTC.balanceOf(holderPair)).toString());
        console.log("WETH Balance of Earnings Manager: ", (await mockWETH.balanceOf(holderPair)).toString());

        pairAddress = await swapFactory.getPair(mockUSDC.address, mockWBTC.address);
        Pair = await ethers.getContractFactory("UniswapV2Pair");
        pair = await Pair.attach(pairAddress);
        holderPair = await pair.HOLDING_ADDRESS();
        console.log("Earnings Manager for pair: ", holderPair);
        console.log("USDC Balance of Earnings Manager: ", (await mockUSDC.balanceOf(holderPair)).toString());
        console.log("WBTC Balance of Earnings Manager: ", (await mockWBTC.balanceOf(holderPair)).toString());

        console.log("Address 2 balances:");
        console.log("WETH Balance: ", (await mockWETH.balanceOf(addr2.address)).toString());
        console.log("WBTC Balance: ", (await mockWBTC.balanceOf(addr2.address)).toString());
        console.log("USDC Balance: ", (await mockUSDC.balanceOf(addr2.address)).toString());
        console.log("DAI  Balance: ", (await mockDAI.balanceOf(addr2.address)).toString());
        
    });

    it("Should allow caller to swap USDC for wBTC", async function () {
        let pairAddress;
        pairAddress = await swapFactory.getPair(mockUSDC.address, mockWBTC.address);
        let Pair = await ethers.getContractFactory("UniswapV2Pair");
        let pair = await Pair.attach(pairAddress);
        let EMforPair = await pair.EM_ADDRESS();
        await mockUSDC.connect(addr2).approve(swapRouter.address, "1000000000000000000000");
        let path = [mockUSDC.address, mockWBTC.address];
        console.log("Swap USDC for wBTC");

        await swapRouter.connect(addr2).swapExactTokensForTokens("1000000000000000000", "90000000000000000", path, addr2.address, 1654341846);



        console.log("Address 2 balances:");
        console.log("WETH Balance: ", (await mockWETH.balanceOf(addr2.address)).toString());
        console.log("WBTC Balance: ", (await mockWBTC.balanceOf(addr2.address)).toString());
        console.log("USDC Balance: ", (await mockUSDC.balanceOf(addr2.address)).toString());
        console.log("DAI  Balance: ", (await mockDAI.balanceOf(addr2.address)).toString());
        
    });

    it("Should allow caller to add liquidity to existing LP pools", async function () {
        
        //Add to wETH wBTC pair
        let pairAddress;
        await mockWETH.connect(addr3).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr3).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr3).addLiquidity(mockWETH.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "900000000000000000000", "90000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockWETH.address, mockWBTC.address);
        console.log("Added to wETH/wBTC at: ", pairAddress);

        //Add to wBTC USDC pair
        await mockUSDC.connect(addr3).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr3).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr3).addLiquidity(mockUSDC.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "900000000000000000000", "90000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockUSDC.address, mockWBTC.address);
        console.log("Added to USDC/wBTC at: ", pairAddress);

        //Add to wBTC GFI pair
        await mockGFI.transfer(addr3.address, "1000000000000000000000");
        await mockGFI.connect(addr3).approve(swapRouter.address, "1000000000000000000000");
        await mockWBTC.connect(addr3).approve(swapRouter.address, "100000000000000000000");
        await swapRouter.connect(addr3).addLiquidity(mockGFI.address, mockWBTC.address, "1000000000000000000000", "100000000000000000000", "900000000000000000000", "90000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockGFI.address, mockWBTC.address);
        console.log("Added to  GFI/wBTC at: ", pairAddress);

    });

    it("Check Pathing", async function () {
        
        //Create DAI/GFI Pair
        let pairAddress;
        await mockGFI.transfer(addr1.address, "1000000000000000000000");
        await mockGFI.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await mockDAI.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await swapRouter.connect(addr1).addLiquidity(mockGFI.address, mockDAI.address, "1000000000000000000000", "1000000000000000000000", "990000000000000000000", "990000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockGFI.address, mockDAI.address);
        console.log("Created  GFI/DAI at: ", pairAddress);

        expect(await pathOracle.pathMap(mockDAI.address)).to.equal(GFI);
        expect(await pathOracle.pathMap(mockGFI.address)).to.equal(WBTC);
        expect(await pathOracle.pathMap(mockWBTC.address)).to.equal(WETH);
        expect(await pathOracle.pathMap(mockWETH.address)).to.equal(WBTC);

        //Check to make sure that a completely random pair fails to create a path(use SUSHI and LINK)
        //Then add a pool that creates a path
        //Then update the path and see if it works
        

    });

    it("Check Fee Logic", async function () {
        let pairAddress;
        let Pair;
        let pair;
        let EMforPair;

        pairAddress = await swapFactory.getPair(mockDAI.address, mockGFI.address);
        Pair = await ethers.getContractFactory("UniswapV2Pair");
        pair = await Pair.attach(pairAddress);
        EMforPair = await pair.EM_ADDRESS();
        let EM = await ethers.getContractFactory("EarningsManager");
        let em = await EM.attach(EMforPair);

        let Oracle = await ethers.getContractFactory("PriceOracle");
        let oracle = await Oracle.attach(priceOracle.address);


        console.log("Earnings Manager for pair: ", EMforPair);
        console.log("GFI Balance of Earnings Manager: ", Number((await mockGFI.balanceOf(EMforPair)).toString())/10**18);
        console.log("DAI Balance of Earnings Manager: ", Number((await mockDAI.balanceOf(EMforPair)).toString())/10**18);
        await mockGFI.transfer(addr4.address, "1000000000000000000000");
        await mockGFI.connect(addr4).approve(swapRouter.address, "10000000000000000000000000");
        await mockDAI.connect(addr4).approve(swapRouter.address, "10000000000000000000000000");
        let path1 = [mockDAI.address, mockGFI.address];
        let path2 = [mockGFI.address, mockDAI.address];
        var i;
        for (i = 0; i < 100; i++) {
            await swapRouter.connect(addr4).swapExactTokensForTokens("100000000000000000000",  "9000000000000000000", path1, addr4.address, 1654341846);
            await swapRouter.connect(addr4).swapExactTokensForTokens("100000000000000000000", "9000000000000000000", path2, addr4.address, 1654341846);
        }

        console.log("Earnings Manager for pair: ", EMforPair);
        console.log("GFI Balance of Earnings Manager: ", Number((await mockGFI.balanceOf(EMforPair)).toString())/10**18);
        console.log("DAI Balance of Earnings Manager: ", Number((await mockDAI.balanceOf(EMforPair)).toString())/10**18);
        

        await pair.updateEM(95);
        await em.checkPricing();

        console.log("Advance time by 300 seconds");
        await network.provider.send("evm_increaseTime", [300]);
        await network.provider.send("evm_mine");

        pair.handleFees();


        console.log("WETH Balance of Governor: ", Number((await mockWETH.balanceOf(governance.address)).toString())/10**18);
        console.log("WBTC Balance of Governor: ", Number((await mockWBTC.balanceOf(governance.address)).toString())/10**18);

    });

    //ADD TEST TO CHECK IF REQUIRE STATEMENT ON LINE 257(Pair contract) works
    //ADD TEST TO SEE IF PAUSING WORKS

    it("Check Earnings Logic", async function () {
        
        //Create wETH/GFI Pair
        let pairAddress;
        await mockGFI.transfer(addr1.address, "100000000000000000000000000");
        await mockGFI.connect(addr1).approve(swapRouter.address, "100000000000000000000000000");
        await mockWETH.connect(addr1).approve(swapRouter.address, "1000000000000000000000");
        await swapRouter.connect(addr1).addLiquidity(mockGFI.address, mockWETH.address, "100000000000000000000000000", "1000000000000000000000", "990000000000000000000", "990000000000000000000", addr1.address, 1654341846);
        pairAddress = await swapFactory.getPair(mockGFI.address, mockWETH.address);
        console.log("Created  GFI/wETH at: ", pairAddress);

        let Pair = await ethers.getContractFactory("UniswapV2Pair");
        let pair = await Pair.attach(pairAddress);
        EMforPair = await pair.EM_ADDRESS();
        let EM = await ethers.getContractFactory("EarningsManager");
        let em = await EM.attach(EMforPair);

        await governance.updateFee(pairAddress);
        await mockWETH.connect(addr1).approve(governance.address, "12000000000000000000"); 
        await governance.connect(addr1).depositFee("12000000000000000000", "0"); //Deposit 12 wETH into governance contract

        await pair.updateEM(95);
        await em.checkPricing();
        console.log("Advance time by 300 seconds");
        await network.provider.send("evm_increaseTime", [300]);
        await network.provider.send("evm_mine");
        console.log( (await em.swapPath(0)).toString(), " -> ", (await em.swapPath(1)).toString(), " -> ", (await em.swapPath(2)).toString(), " -> ", (await em.swapPath(3)).toString(), " -> ", (await em.swapPath(4)).toString())
        console.log( (await em.swapCount()).toString());
        
        console.log("Swap Pair wETH Balance: ",(await mockWETH.balanceOf(pairAddress)).toString());
        console.log("Swap Pair GFI Balance: ",(await mockGFI.balanceOf(pairAddress)).toString());
        console.log("Earnings Manager LP token balance: ", (await pair.balanceOf(EMforPair)).toString());
        console.log("Earnings Manager wETH Balance: ",(await mockWETH.balanceOf(EMforPair)).toString());
        console.log("Earnings Manager GFI Balance: ",(await mockGFI.balanceOf(EMforPair)).toString());
        console.log("");
        console.log("Convert GFI earnings into pool assets, deposit them, then burn LP tokens");
        await pair.handleEarnings();
        console.log("");
        console.log("Swap Pair wETH Balance: ",(await mockWETH.balanceOf(pairAddress)).toString());
        console.log("Swap Pair GFI Balance: ",(await mockGFI.balanceOf(pairAddress)).toString());
        console.log("Earnings Manager LP token balance: ", (await pair.balanceOf(EMforPair)).toString());
        console.log("Earnings Manager wETH Balance: ",(await mockWETH.balanceOf(EMforPair)).toString());
        console.log("Earnings Manager GFI Balance: ",(await mockGFI.balanceOf(EMforPair)).toString());


    });




});