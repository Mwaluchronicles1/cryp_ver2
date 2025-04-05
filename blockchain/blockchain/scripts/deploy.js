// Script to deploy the DocumentVerification contract
const { ethers } = require("hardhat");

async function main() {
  // Get the contract factory
  const DocumentVerification = await ethers.getContractFactory("DocumentVerification");
  
  console.log("Deploying DocumentVerification contract...");
  
  // Deploy the contract
  const documentVerification = await DocumentVerification.deploy();
  
  // Wait for deployment to finish
  await documentVerification.deployed();
  
  console.log("DocumentVerification deployed to:", documentVerification.address);
  
  // Additional log to help the user understand what's happening
  console.log("Document Verification Platform is now live on the blockchain!");
  console.log("Contract owner and first authorized verifier:", await documentVerification.owner());
}

// Execute the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error during deployment:", error);
    process.exit(1);
  }); 