# Infura Setup for Document Verification Platform

This guide provides step-by-step instructions for setting up an Infura project and integrating it with the Document Verification Platform for test and production environments.

## Creating an Infura Account

1. **Sign Up for Infura**:
   - Visit [https://infura.io/](https://infura.io/)
   - Click "Sign Up" to create a new account
   - Complete the registration process

2. **Log In to Your Account**:
   - Navigate to [https://infura.io/login](https://infura.io/login)
   - Enter your credentials and log in

## Creating an Infura Project

1. **Create a New Project**:
   - From the Infura dashboard, click "Create New Project"
   - Select "Ethereum" as the product
   - Enter a project name (e.g., "Document Verification")
   - Click "Create"

2. **Access Project Settings**:
   - After creation, you'll be redirected to the project dashboard
   - Here you can view your project ID (API Key) and network endpoints

3. **Note Your API Key**:
   - The Project ID (API Key) is displayed at the top of the page
   - This key will be used to authenticate your application with Infura

4. **Select Network**:
   - Infura provides access to multiple Ethereum networks
   - For development and testing, select "Sepolia" or "Goerli" testnet
   - For production, select "Mainnet"
   - Note the network endpoint URLs (they contain your API key)

## Configuring the Document Verification Platform

### Updating Hardhat Configuration

1. **Edit `blockchain/.env` File**:
   - Open the `.env` file in the blockchain directory
   - Add or update the following line:
   ```
   INFURA_API_KEY=your_infura_project_id
   ```
   - Replace `your_infura_project_id` with the actual Project ID from Infura

2. **Configure the Network in `hardhat.config.js`**:
   - The configuration should already be set up for Infura
   - Verify that the network configuration matches your desired testnet:

   ```javascript
   infura: {
     url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
     accounts: PRIVATE_KEY ? [`0x${PRIVATE_KEY}`] : [],
     chainId: 11155111, // Sepolia testnet
   }
   ```

3. **Add Your Private Key for Deployment**:
   - In the `blockchain/.env` file, add your wallet's private key:
   ```
   PRIVATE_KEY=your_private_key_without_0x_prefix
   ```
   - This wallet will be used to deploy contracts and must have sufficient ETH

### Deploying Contracts to Testnet via Infura

1. **Get Testnet ETH**:
   - For Sepolia: Visit the Sepolia faucet at [https://faucet.sepolia.dev/](https://faucet.sepolia.dev/)
   - For Goerli: Visit the Goerli faucet at [https://goerlifaucet.com/](https://goerlifaucet.com/)
   - Request test ETH to your wallet address

2. **Deploy the Contract**:
   - Run the deployment script with the Infura network:
   ```
   npx hardhat run scripts/deploy.js --network infura
   ```
   - This will deploy the contract to the specified testnet through Infura

3. **Verify Contract Deployment**:
   - After successful deployment, note the contract address from console output
   - You can verify the contract on the relevant block explorer:
     - Sepolia: [https://sepolia.etherscan.io/](https://sepolia.etherscan.io/)
     - Goerli: [https://goerli.etherscan.io/](https://goerli.etherscan.io/)
     - Mainnet: [https://etherscan.io/](https://etherscan.io/)

### Updating Flutter App Configuration

1. **Edit Flutter `.env` File**:
   - Open the `.env` file in the main Flutter app directory
   - Update the following lines:
   ```
   INFURA_API_KEY=your_infura_project_id
   CONTRACT_ADDRESS=your_deployed_contract_address
   ```

2. **Configure Network in the App**:
   - The app should automatically connect to the appropriate Infura endpoint
   - Ensure the network matches the one where you deployed your contract

## Testing the Infura Integration

1. **Run the Flutter App**:
   - Launch the Flutter app on your device or emulator

2. **Connect Your Wallet**:
   - Ensure your wallet (MetaMask or other) is connected to the same network
   - For testnet testing, switch to Sepolia or Goerli in your wallet

3. **Test Document Registration**:
   - Select a document and provide metadata
   - Attempt to register it on the blockchain
   - The transaction should be routed through Infura to the Ethereum network

4. **Verify Transaction**:
   - Check the transaction status in your wallet
   - You can also verify it on the blockchain explorer by searching for the transaction hash

## Optimizing Infura Usage

1. **Monitor Your Usage**:
   - Infura has usage limits depending on your plan
   - Monitor your usage from the Infura dashboard
   - Set up alerts for approaching limits

2. **Caching and Optimizing Requests**:
   - Implement caching for read operations to reduce Infura API calls
   - Batch operations when possible
   - Don't poll the blockchain too frequently

3. **Minimize Transaction Data**:
   - Optimize the amount of data sent in each transaction
   - Store large documents off-chain and only put hashes on the blockchain

## Moving to Production

1. **Upgrade Infura Plan (If Needed)**:
   - Free tier may be sufficient for testing
   - For production, consider upgrading to a paid plan for better rate limits and support

2. **Deploy to Mainnet**:
   - Update `hardhat.config.js` to use Ethereum mainnet
   - Ensure your wallet has real ETH for deployment and transactions
   - Deploy using the same process, but with the mainnet network

3. **Update Security Measures**:
   - Use environment variables for all sensitive data
   - Consider additional security for private key management
   - Implement rate limiting in your app to prevent excessive Infura usage

4. **Monitor and Maintain**:
   - Regularly check your Infura dashboard for usage and performance
   - Set up notifications for any service disruptions
   - Keep your API keys secure and rotate them periodically

## Troubleshooting

1. **Connection Issues**:
   - Verify your Infura API key is correct
   - Check the network URL is properly formatted
   - Ensure your internet connection is stable

2. **Rate Limiting**:
   - If you hit rate limits, consider optimizing your requests
   - Upgrade your Infura plan if necessary
   - Implement backoff strategies for failed requests

3. **Transaction Failures**:
   - Check that your wallet has sufficient ETH for gas
   - Verify gas settings are appropriate for current network conditions
   - Ensure the contract ABI matches your deployed contract

## Conclusion

With Infura properly integrated into your Document Verification Platform, you now have a reliable, scalable connection to the Ethereum blockchain. This setup allows your application to interact with the blockchain without the need to run your own Ethereum node, significantly reducing infrastructure complexity and costs.

For production environments, always ensure you have proper monitoring, security, and contingency plans in place to handle any potential issues with the Infura service. 