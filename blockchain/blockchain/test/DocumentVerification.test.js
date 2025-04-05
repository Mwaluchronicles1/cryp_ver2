const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DocumentVerification", function () {
  let documentVerification;
  let owner;
  let verifier;
  let user;
  let documentHash;
  
  beforeEach(async function () {
    // Get signers
    [owner, verifier, user] = await ethers.getSigners();
    
    // Deploy the contract
    const DocumentVerification = await ethers.getContractFactory("DocumentVerification");
    documentVerification = await DocumentVerification.deploy();
    await documentVerification.deployed();
    
    // Create a document hash for testing
    documentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("test document"));
  });
  
  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await documentVerification.owner()).to.equal(owner.address);
    });
    
    it("Should set the owner as an authorized verifier", async function () {
      expect(await documentVerification.authorizedVerifiers(owner.address)).to.equal(true);
    });
  });
  
  describe("Verifier Management", function () {
    it("Should allow owner to add a verifier", async function () {
      await documentVerification.addVerifier(verifier.address);
      expect(await documentVerification.authorizedVerifiers(verifier.address)).to.equal(true);
    });
    
    it("Should allow owner to remove a verifier", async function () {
      await documentVerification.addVerifier(verifier.address);
      await documentVerification.removeVerifier(verifier.address);
      expect(await documentVerification.authorizedVerifiers(verifier.address)).to.equal(false);
    });
    
    it("Should not allow non-owner to add a verifier", async function () {
      await expect(
        documentVerification.connect(user).addVerifier(verifier.address)
      ).to.be.revertedWith("Only owner can call this function");
    });
  });
  
  describe("Document Registration", function () {
    it("Should allow any user to register a document", async function () {
      await documentVerification.connect(user).registerDocument(documentHash, "ipfs://metadata");
      
      const [metadataURI, docOwner, status, timestamp] = await documentVerification.getDocumentInfo(documentHash);
      
      expect(metadataURI).to.equal("ipfs://metadata");
      expect(docOwner).to.equal(user.address);
      expect(status).to.equal(0); // Pending status
      expect(timestamp).to.be.gt(0);
    });
    
    it("Should not allow registering the same document twice", async function () {
      await documentVerification.connect(user).registerDocument(documentHash, "ipfs://metadata");
      
      await expect(
        documentVerification.connect(user).registerDocument(documentHash, "ipfs://metadata2")
      ).to.be.revertedWith("Document already registered");
    });
  });
  
  describe("Document Verification", function () {
    beforeEach(async function () {
      // Add verifier
      await documentVerification.addVerifier(verifier.address);
      
      // Register a document
      await documentVerification.connect(user).registerDocument(documentHash, "ipfs://metadata");
    });
    
    it("Should allow verifier to update document status", async function () {
      await documentVerification.connect(verifier).updateDocumentStatus(documentHash, 1); // Verified
      
      const [, , status, ] = await documentVerification.getDocumentInfo(documentHash);
      expect(status).to.equal(1); // Verified status
    });
    
    it("Should track verifier's verification", async function () {
      await documentVerification.connect(verifier).updateDocumentStatus(documentHash, 1);
      
      expect(await documentVerification.hasVerified(documentHash, verifier.address)).to.equal(true);
      expect(await documentVerification.getVerifierCount(documentHash)).to.equal(1);
    });
    
    it("Should not allow unauthorized users to verify documents", async function () {
      await expect(
        documentVerification.connect(user).updateDocumentStatus(documentHash, 1)
      ).to.be.revertedWith("Not authorized");
    });
    
    it("Should not allow verifying a non-existent document", async function () {
      const nonExistentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("nonexistent"));
      
      await expect(
        documentVerification.connect(verifier).updateDocumentStatus(nonExistentHash, 1)
      ).to.be.revertedWith("Document does not exist");
    });
    
    it("Should not allow verifying the same document twice by the same verifier", async function () {
      await documentVerification.connect(verifier).updateDocumentStatus(documentHash, 1);
      
      await expect(
        documentVerification.connect(verifier).updateDocumentStatus(documentHash, 2)
      ).to.be.revertedWith("Already verified by this address");
    });
  });
}); 