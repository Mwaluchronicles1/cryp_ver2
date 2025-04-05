require("dotenv").config();
require("@nomiclabs/hardhat-ethers");

const { INFURA_API_KEY, PRIVATE_KEY } = process.env;

// Default mnemonic for development
const DEFAULT_MNEMONIC = "crater home balance question fresh gaze actual fever energy smile elbow tool";

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      // For hardhat local blockchain testing
    },
    ganache: {
      url: "http://127.0.0.1:7545", // Default Ganache GUI URL
      chainId: 1337,
      accounts: {
        mnemonic: DEFAULT_MNEMONIC,
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 10
      }
    },
    // Comment out Sepolia for now until we have proper credentials
    /*
    sepolia: {
      url: INFURA_API_KEY ? `https://sepolia.infura.io/v3/${INFURA_API_KEY}` : "",
      accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
      chainId: 11155111
    }
    */
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 40000
  }
}; 