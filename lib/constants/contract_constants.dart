class ContractConstants {
  static const String documentVerificationAbi = '''
{
  "abi": [
    {
      "inputs": [],
      "stateMutability": "nonpayable",
      "type": "constructor"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": true,
          "internalType": "bytes32",
          "name": "documentHash",
          "type": "bytes32"
        },
        {
          "indexed": true,
          "internalType": "address",
          "name": "owner",
          "type": "address"
        },
        {
          "indexed": false,
          "internalType": "uint256",
          "name": "timestamp",
          "type": "uint256"
        }
      ],
      "name": "DocumentRegistered",
      "type": "event"
    },
    {
      "anonymous": false,
      "inputs": [
        {
          "indexed": true,
          "internalType": "bytes32",
          "name": "documentHash",
          "type": "bytes32"
        },
        {
          "indexed": false,
          "internalType": "enum DocumentVerification.Status",
          "name": "status",
          "type": "uint8"
        },
        {
          "indexed": true,
          "internalType": "address",
          "name": "verifier",
          "type": "address"
        }
      ],
      "name": "DocumentStatusChanged",
      "type": "event"
    },
    {
      "inputs": [
        {
          "internalType": "bytes32",
          "name": "documentHash",
          "type": "bytes32"
        },
        {
          "internalType": "string",
          "name": "metadataURI",
          "type": "string"
        }
      ],
      "name": "registerDocument",
      "outputs": [],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {
          "internalType": "bytes32",
          "name": "documentHash",
          "type": "bytes32"
        }
      ],
      "name": "getDocumentInfo",
      "outputs": [
        {
          "internalType": "string",
          "name": "metadataURI",
          "type": "string"
        },
        {
          "internalType": "address",
          "name": "documentOwner",
          "type": "address"
        },
        {
          "internalType": "enum DocumentVerification.Status",
          "name": "status",
          "type": "uint8"
        },
        {
          "internalType": "uint256",
          "name": "timestamp",
          "type": "uint256"
        }
      ],
      "stateMutability": "view",
      "type": "function"
    }
  ]
}
''';
} 