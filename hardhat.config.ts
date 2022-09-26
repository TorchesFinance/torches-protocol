import 'dotenv/config';
import {HardhatUserConfig} from 'hardhat/types';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-contract-sizer';
import 'hardhat-storage-layout';
import './tasks';

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  solidity: {
    compilers: [
      {
        version: '0.5.17',
        settings: {
          optimizer: {
            enabled: true,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://rpc-mainnet.kcc.network`
      }
    },
    km: {
      url: `https://rpc-mainnet.kcc.network`,
      chainId: 321,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ''}`]
    },
    kt: {
      url: 'https://rpc-testnet.kcc.network',
      chainId: 322,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ''}`]
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      chainId: 80001,
      accounts: [`0x${process.env.DEPLOY_PRIVATE_KEY ?? ''}`]
    },
  },
};

export default config;
