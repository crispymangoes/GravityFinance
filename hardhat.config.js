require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("@openzeppelin/hardhat-upgrades");
const { mnemonic } = require('./secrets.json');
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000
          }
        }
      },
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000
          }
        }
      }
    ]
  },
  networks: {
    mumbai: {
      url: `https://rpc-mumbai.maticvigil.com`,
      accounts: {mnemonic: mnemonic}
    },
    polygon: {
      url: `https://rpc-mainnet.maticvigil.com`,
      accounts: {mnemonic: mnemonic}
    },
    xDai: {
      url: `https://rpc.xdaichain.com/`,
      accounts: {mnemonic: mnemonic}
    }
  },
  mocha: {
    timeout: 200000
  },
  gasReporter: {
    currency: 'USD'
  }
};
