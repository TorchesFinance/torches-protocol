import "dotenv/config";
import { HardhatUserConfig } from "hardhat/types";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";
import "hardhat-storage-layout";
import "./tasks";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.5.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: 0,
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://rpc-mainnet.kcc.network`,
      },
    },
    km: {
      url: `https://rpc-mainnet.kcc.network`,
      chainId: 321,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ""}`],
      gasMultiplier: 1,
      gasPrice: 1000000000,
    },
    kt: {
      url: "https://rpc-testnet.kcc.network",
      chainId: 322,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ""}`],
      gasMultiplier: 1,
      gasPrice: 1000000000,
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      chainId: 80001,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ""}`],
    },
  },
  etherscan: {
    apiKey: {
      kt: "abc",
      km: "abc",
    },
    customChains: [
      {
        network: "km",
        chainId: 321,
        urls: {
          apiURL: "https://scan.kcc.io/api",
          browserURL: "https://scan.kcc.io/",
        },
      },
      {
        network: "kt",
        chainId: 322,
        urls: {
          apiURL: "https://scan-testnet.kcc.network/api",
          browserURL: "https://scan-testnet.kcc.network/",
        },
      },
    ],
  },
};

export default config;
