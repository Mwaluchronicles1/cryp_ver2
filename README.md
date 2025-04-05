# Document Verification Platform

A decentralized document verification platform built with Ethereum blockchain technology and Flutter. This application allows users to securely register documents on the blockchain and verify their authenticity.

## Features

- Document registration by storing cryptographic hashes on the blockchain
- Verification mechanism for documents
- Immutable audit trail of all transactions
- User-friendly Flutter interface
- Wallet integration for secure transactions

## Technology Stack

- **Blockchain**: Ethereum (Hardhat, Solidity)
- **Development Environment**: Ganache for local blockchain testing
- **Network Access**: Infura API for testnet/mainnet access
- **User Interface**: Flutter for cross-platform mobile/web app
- **Wallet Integration**: Web3 connectivity

## Setup Instructions

### Prerequisites

- Node.js and npm
- Flutter SDK
- Ganache (GUI or CLI version)
- Infura Account
- MetaMask or another Ethereum wallet

### Blockchain Setup

1. **Install Ganache GUI**:
   - Download and install from [https://www.trufflesuite.com/ganache](https://www.trufflesuite.com/ganache)
   - Launch Ganache and create a new workspace
   - Note the RPC URL (usually http://127.0.0.1:7545)

2. **Install Hardhat dependencies**:
   - Navigate to the blockchain directory: `cd blockchain`
   - Install dependencies manually if npm command doesn't work (see hardhat.config.js for required dependencies)

3. **Configure Hardhat**:
   - Edit `blockchain/.env` file with your Infura API key
   - Update the mnemonic in hardhat.config.js if you want to use a specific one

4. **Deploy Smart Contracts**:
   - Ensure Ganache is running
   - Deploy contracts to Ganache
   - Note the deployed contract address

5. **Update Flutter Environment**:
   - Edit `.env` with the contract address and Infura API key
   - Ensure your wallet has ETH for transactions (on Ganache or testnet)

### Flutter Setup

1. **Install Flutter Dependencies**:
   - Run: `flutter pub get`

2. **Run the App**:
   - Connect a device or emulator
   - Run: `flutter run`

## Usage

### Registering a Document

1. Connect your wallet (MetaMask or compatible wallet)
2. Select a document to upload
3. The app will calculate a cryptographic hash of the document
4. Enter metadata for the document
5. Click "Register Document" to store the hash on the blockchain

### Verifying a Document

1. Select a document to verify
2. The app will calculate the hash and check it against the blockchain
3. View the verification status (Pending, Verified, or Rejected)
4. Review document metadata and history

## Wallet Integration

The application connects to MetaMask or other compatible wallets to sign transactions. For testing:

1. Add Ganache to your MetaMask as a custom RPC:
   - Network Name: Ganache
   - RPC URL: http://127.0.0.1:7545
   - Chain ID: 1337
   - Currency Symbol: ETH

2. Import a Ganache account to MetaMask:
   - Get a private key from Ganache
   - Import to MetaMask using the "Import Account" feature

## Security Considerations

- Never share your private keys or mnemonic phrases
- For production use, conduct proper security audits of smart contracts
- Consider gas optimization for contract deployment and interactions

## License

MIT
