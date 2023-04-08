require("@nomiclabs/hardhat-ethers")
require("@nomicfoundation/hardhat-network-helpers")
require("@nomicfoundation/hardhat-toolbox")

module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.2",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        }
      },
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://rpc.ankr.com/eth",
        blockNumber: 16948000
      },
      chainId: 1,
    },
  },
  paths: {
    sources: 'contracts',
  },
};
