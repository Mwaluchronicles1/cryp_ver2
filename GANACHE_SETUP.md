# Ganache GUI Setup for Document Verification Platform

This guide provides step-by-step instructions for setting up Ganache GUI and integrating it with the Document Verification Platform.

## Installing Ganache GUI

1. **Download Ganache**:
   - Visit [https://www.trufflesuite.com/ganache](https://www.trufflesuite.com/ganache)
   - Download the appropriate version for your operating system (Windows, macOS, or Linux)

2. **Install Ganache**:
   - Run the installer and follow the on-screen instructions
   - Launch Ganache once installation is complete

## Setting Up a Ganache Workspace

1. **Create a New Workspace**:
   - Open Ganache
   - Click on "New Workspace"
   - Select "Ethereum" as the workspace type

2. **Configure Workspace Settings**:
   - **Workspace Name**: Enter a name for your workspace (e.g., "DocumentVerification")
   - **Server Settings**:
     - Hostname: 127.0.0.1 (default)
     - Port Number: 7545 (default)
     - Network ID: 1337 (recommended for local development)
   - **Accounts & Keys**:
     - Number of accounts: 10 (default)
     - Default account balance: 100 ETH (default)
     - Auto-generate HD Mnemonic: Make note of this for hardhat.config.js

3. **Advanced Settings (Optional)**:
   - Gas Limit: 6721975 (default)
   - Gas Price: 20000000000 (default)
   - Hardfork: Petersburg (or other appropriate version)

4. **Save Workspace**:
   - Click "Save Workspace" to create and launch your workspace

## Configuring Hardhat to Use Ganache

1. **Edit `hardhat.config.js`**:
   - Update the Ganache network configuration to match your Ganache settings:

```javascript
ganache: {
  url: "http://127.0.0.1:7545", // Match Ganache GUI URL
  chainId: 1337, // Match Ganache network ID
  accounts: {
    mnemonic: "your ganache mnemonic here", // Use the mnemonic from Ganache
  },
}
```

2. **Check Connection**:
   - Ensure Ganache is running
   - Run a simple test to verify the connection:
   - If you have Node.js working, you could run: `npx hardhat console --network ganache`

## Deploying Contracts to Ganache

1. **Ensure Ganache is Running**:
   - Make sure your Ganache workspace is active

2. **Deploy the Contract**:
   - Navigate to the blockchain directory
   - Run the deployment script (assuming npm/Node.js are working):
   - Command: `npx hardhat run scripts/deploy.js --network ganache`
   - If npm/Node.js aren't working, you might need to manually deploy using Remix and connect it to Ganache

3. **Note the Contract Address**:
   - After successful deployment, note the contract address
   - This will be displayed in the console output
   - You can also see the transaction in the Ganache GUI under the "Transactions" tab

4. **Update the Flutter App Configuration**:
   - Edit the `.env` file in the Flutter app root directory
   - Set `CONTRACT_ADDRESS=your_deployed_contract_address`

## Setting Up MetaMask with Ganache

1. **Install MetaMask Extension**:
   - Install the MetaMask browser extension from [https://metamask.io/](https://metamask.io/)

2. **Create or Import a Wallet**:
   - Follow MetaMask instructions to create a new wallet or import an existing one

3. **Connect MetaMask to Ganache**:
   - Click on the network dropdown at the top of MetaMask
   - Select "Add Network" or "Custom RPC"
   - Enter the following details:
     - Network Name: Ganache
     - New RPC URL: http://127.0.0.1:7545
     - Chain ID: 1337
     - Currency Symbol: ETH
   - Click "Save"

4. **Import Ganache Accounts to MetaMask (Optional)**:
   - In Ganache, click on a key icon next to an account to reveal the private key
   - In MetaMask, click on the account icon > "Import Account"
   - Paste the private key and click "Import"

## Testing the Integration

1. **Start the Flutter App**:
   - Run the Flutter app on your device or emulator

2. **Connect Wallet**:
   - In the app, click "Connect Wallet"
   - If on mobile, ensure you have a wallet app installed
   - If on web, MetaMask should prompt for connection

3. **Register a Document**:
   - Select a document to register
   - Provide metadata URL
   - Click "Register Document"
   - Approve the transaction in MetaMask

4. **Verify the Transaction in Ganache**:
   - In Ganache GUI, check the "Transactions" tab
   - You should see your contract interaction transaction
   - You can click on it to see details

5. **Check Contract State**:
   - In Ganache GUI, go to the "Contracts" tab
   - If you've deployed the contract via Hardhat, the contract should be visible
   - You can inspect its current state and events

## Troubleshooting

1. **Connection Issues**:
   - Ensure Ganache is running before deploying contracts or testing
   - Check that port 7545 is not blocked by a firewall
   - Verify network ID matches in both Ganache and hardhat.config.js

2. **Transaction Errors**:
   - Check gas settings in Ganache
   - Ensure account has sufficient ETH for gas fees
   - Verify contract ABI matches deployed contract

3. **MetaMask Issues**:
   - Reset the account if transactions are stuck (Settings > Advanced > Reset Account)
   - Ensure you're connected to the correct network
   - Check that transaction nonce is correct

## Conclusion

With Ganache GUI properly configured and integrated with your Document Verification Platform, you now have a complete local blockchain development environment. This setup allows you to test all aspects of the application without spending real ETH or deploying to a public testnet.

For a production deployment, you would follow similar steps but connect to Infura instead of Ganache, and deploy to a public testnet or mainnet.