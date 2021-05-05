async function main() {
    const CONTRACT_OWNER = "0xeb678812778B68a48001B4A9A4A04c4924c33598";
    const WETH_ADDRESS = "0x3C68CE8504087f89c640D02d133646d98e64ddd9";
    [deployer] = await ethers.getSigners();
    console.log("Deployer address:", deployer.address);
    console.log("");
    /**
     * @dev Deploy the Gravity Token Contract
     */
    const GravityToken = await ethers.getContractFactory("GravityToken");
    console.log("Deploying GravityToken...");
    const gravityToken = await GravityToken.deploy("Gravity Finance", "GFI");
    console.log("GravityToken deployed to:", gravityToken.address);
    console.log("");
    /**
     * @dev Deploy the IDO contract
     */
    const GravityIDO = await ethers.getContractFactory("GravityIDO");
    console.log("Deploying GravityIDO...");
    const gravityIDO = await GravityIDO.deploy(WETH_ADDRESS, gravityToken.address, 0, true);
    console.log("GravityIDO deployed to:", gravityIDO.address);
    console.log("");

    console.log("Transferring sale tokens to IDO...");
    await gravityToken.transfer(gravityIDO.address, "40000000000000000000000000"); //Send 40,000,000 GFI to IDO address
    let deployerBal = (await gravityToken.balanceOf(deployer.address)).toString();
    console.log("Transferring remaining token balance to contract owner...");
    await gravityToken.transfer(CONTRACT_OWNER, deployerBal); //Transfer remaining tokens to CONTRACT_OWNER
    console.log("Transferring token owenership to contract owner...");
    await gravityToken.transferOwnership(CONTRACT_OWNER);
    console.log("Transferring IDO ownership to contract owner...");
    await gravityIDO.transferOwnership(CONTRACT_OWNER);
    console.log("");
    console.log("Summary");
    console.log("Gravity Token Address:", gravityToken.address);
    console.log("WETH Address:", WETH_ADDRESS);
    console.log("Gravity IDO Address:", gravityIDO.address);
    console.log("IDO IOU Token Address: ", await gravityIDO.getIOUAddress());
    console.log("Contract Owner Address: ", CONTRACT_OWNER);

  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });