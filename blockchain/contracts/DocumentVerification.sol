// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DocumentVerification
 * @dev Smart contract for secure document registration and verification on blockchain
 */
contract DocumentVerification {
    enum Status { Pending, Verified, Rejected }
    
    struct Document {
        bytes32 documentHash;      // Cryptographic hash of the document
        string metadataURI;        // URI pointing to metadata (IPFS or other storage)
        address owner;             // Owner of the document
        Status status;             // Current verification status
        uint256 timestamp;         // Timestamp when document was registered
        address[] verifiers;       // List of addresses that verified this document
        mapping(address => bool) hasVerified; // Mapping to track if an address has verified
    }
    
    // Documents mapped by their hashes
    mapping(bytes32 => Document) private documents;
    
    // Authorized verifiers
    mapping(address => bool) public authorizedVerifiers;
    
    // Owner of the contract
    address public owner;
    
    // Events
    event DocumentRegistered(bytes32 indexed documentHash, address indexed owner, uint256 timestamp);
    event DocumentStatusChanged(bytes32 indexed documentHash, Status status, address indexed verifier);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }
    
    modifier documentExistsModifier(bytes32 documentHash) {
        require(documents[documentHash].owner != address(0), "Document does not exist");
        _;
    }
    
    modifier notYetVerified(bytes32 documentHash) {
        require(!documents[documentHash].hasVerified[msg.sender], "Already verified by this address");
        _;
    }
    
    /**
     * @dev Constructor sets deployer as owner
     */
    constructor() {
        owner = msg.sender;
        authorizedVerifiers[msg.sender] = true; // Owner is automatically an authorized verifier
    }
    
    /**
     * @dev Register a new document with its hash and metadata
     * @param documentHash The cryptographic hash of the document
     * @param metadataURI URI pointing to document metadata
     */
    function registerDocument(bytes32 documentHash, string memory metadataURI) external {
        require(documents[documentHash].owner == address(0), "Document already registered");
        
        Document storage newDoc = documents[documentHash];
        newDoc.documentHash = documentHash;
        newDoc.metadataURI = metadataURI;
        newDoc.owner = msg.sender;
        newDoc.status = Status.Pending;
        newDoc.timestamp = block.timestamp;
        
        emit DocumentRegistered(documentHash, msg.sender, block.timestamp);
    }
    
    /**
     * @dev Update document verification status
     * @param documentHash The hash of the document to verify
     * @param newStatus The new status to set
     */
    function updateDocumentStatus(bytes32 documentHash, Status newStatus) 
        external 
        onlyAuthorizedVerifier 
        documentExistsModifier(documentHash)
        notYetVerified(documentHash)
    {
        Document storage doc = documents[documentHash];
        doc.status = newStatus;
        doc.verifiers.push(msg.sender);
        doc.hasVerified[msg.sender] = true;
        
        emit DocumentStatusChanged(documentHash, newStatus, msg.sender);
    }
    
    /**
     * @dev Add a new authorized verifier
     * @param verifier Address of the verifier to add
     */
    function addVerifier(address verifier) external onlyOwner {
        require(verifier != address(0), "Invalid address");
        require(!authorizedVerifiers[verifier], "Already a verifier");
        
        authorizedVerifiers[verifier] = true;
        emit VerifierAdded(verifier);
    }
    
    /**
     * @dev Remove an authorized verifier
     * @param verifier Address of the verifier to remove
     */
    function removeVerifier(address verifier) external onlyOwner {
        require(authorizedVerifiers[verifier], "Not a verifier");
        require(verifier != owner, "Cannot remove owner as verifier");
        
        authorizedVerifiers[verifier] = false;
        emit VerifierRemoved(verifier);
    }
    
    /**
     * @dev Get document information
     * @param documentHash The hash of the document to get
     * @return metadataURI The URI of document metadata
     * @return documentOwner The owner of the document
     * @return status The current verification status
     * @return timestamp When the document was registered
     */
    function getDocumentInfo(bytes32 documentHash) 
        external 
        view 
        documentExistsModifier(documentHash)
        returns (
            string memory metadataURI,
            address documentOwner,
            Status status,
            uint256 timestamp
        ) 
    {
        Document storage doc = documents[documentHash];
        return (
            doc.metadataURI,
            doc.owner,
            doc.status,
            doc.timestamp
        );
    }
    
    /**
     * @dev Check if a document exists
     * @param documentHash The hash of the document to check
     * @return exists True if the document exists
     */
    function documentExists(bytes32 documentHash) public view returns (bool) {
        return documents[documentHash].owner != address(0);
    }
    
    /**
     * @dev Get the number of verifiers for a document
     * @param documentHash The hash of the document
     * @return count The number of verifiers
     */
    function getVerifierCount(bytes32 documentHash) 
        external 
        view 
        documentExistsModifier(documentHash)
        returns (uint256) 
    {
        return documents[documentHash].verifiers.length;
    }
    
    /**
     * @dev Check if an address has verified a document
     * @param documentHash The hash of the document
     * @param verifier The address to check
     * @return verified True if the address has verified the document
     */
    function hasVerified(bytes32 documentHash, address verifier) 
        external 
        view 
        documentExistsModifier(documentHash)
        returns (bool) 
    {
        return documents[documentHash].hasVerified[verifier];
    }
} 