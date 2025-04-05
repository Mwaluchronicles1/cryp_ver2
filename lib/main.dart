import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants/contract_constants.dart';
import 'utils/document_metadata_extractor.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const DocumentVerificationApp());
}

class DocumentVerificationApp extends StatelessWidget {
  const DocumentVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Verification Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        cardTheme: CardTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Web3Client? _ethClient;
  DeployedContract? _contract;

  bool _isLoading = false;
  bool _isConnected = false;
  String _walletAddress = '';
  String _privateKey = '';
  String _contractAddress = '';
  String _errorMessage = '';
  String _rpcUrl = '';

  FilePickerResult? _selectedFile;
  String _fileHash = '';
  DocumentMetadata? _documentMetadata;
  
  // Audit trail
  List<Map<String, dynamic>> _auditTrail = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ethClient?.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      // Load Sepolia settings
      final infuraApiKey = dotenv.env['INFURA_API_KEY'] ?? '';
      final contractAddress = dotenv.env['CONTRACT_ADDRESS'] ?? '';

      // Load Ganache settings
      final ganacheContractAddress = dotenv.env['GANACHE_CONTRACT_ADDRESS'] ?? '';
      final ganacheRpcUrl = dotenv.env['GANACHE_RPC_URL'] ?? 'http://127.0.0.1:7545';

      // Set Sepolia as default network settings
      if (contractAddress.isNotEmpty) {
        setState(() {
          _contractAddress = contractAddress;
        });
      }

      if (infuraApiKey.isNotEmpty) {
        setState(() {
          _rpcUrl = 'https://sepolia.infura.io/v3/$infuraApiKey';
        });
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading configuration: ${e.toString()}';
      });
    }
  }

  Future<void> _setupWeb3() async {
    if (_contractAddress.isEmpty) {
      setState(() {
        _errorMessage = 'Contract address is required';
      });
      return;
    }

    if (_rpcUrl.isEmpty) {
      setState(() {
        _errorMessage = 'RPC URL is required';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final httpClient = Client();
      _ethClient = Web3Client(_rpcUrl, httpClient);

      try {
        // Parse the ABI from our constants
        final jsonABI = jsonDecode(ContractConstants.documentVerificationAbi);
        final abi = jsonABI['abi'];

        if (abi == null) {
          throw Exception('ABI not found in JSON');
        }

        // Ensure contract address is properly formatted
        final contractAddress = EthereumAddress.fromHex(_contractAddress);
        _contract = DeployedContract(
            ContractAbi.fromJson(jsonEncode(abi), 'DocumentVerification'),
            contractAddress
        );

        // Validate wallet address and private key
        if (_walletAddress.isEmpty) {
          throw Exception('Wallet address is required');
        }

        if (_privateKey.isEmpty) {
          throw Exception('Private key is required');
        }

        // Ensure wallet address is valid
        final ethAddress = EthereumAddress.fromHex(_walletAddress);

        // Test that we can create credentials with the private key
        // Remove '0x' prefix if present to prevent double prefixing
        final cleanPrivateKey = _privateKey.startsWith('0x')
            ? _privateKey.substring(2)
            : _privateKey;

        final credentials = EthPrivateKey.fromHex(cleanPrivateKey);

        setState(() {
          _isConnected = true;
          _isLoading = false;
          _errorMessage = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet connected successfully')),
        );
      } catch (e) {
        throw Exception('Error parsing contract ABI: ${e.toString()}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error connecting to blockchain: ${e.toString()}';
        _isConnected = false;
      });
    }
  }

  Future<void> _disconnectWallet() async {
    setState(() {
      _isConnected = false;
      _walletAddress = '';
      _privateKey = '';
      _ethClient?.dispose();
      _ethClient = null;
      _contract = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wallet disconnected')),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true, // This ensures we get the bytes on all platforms
      );

      if (result != null) {
        setState(() {
          _selectedFile = result;
          _fileHash = '';
          _documentMetadata = null;
        });

        // Extract metadata from the file
        try {
          final metadata = await DocumentMetadataExtractor.extractMetadata(result);
          setState(() {
            _documentMetadata = metadata;
            _fileHash = metadata.hash;
          });
          
          // Add to audit trail
          _addToAuditTrail('FILE_SELECTED', {
            'fileName': metadata.fileName,
            'fileType': metadata.fileType,
            'fileSize': metadata.fileSize,
            'hash': metadata.hash
          });
        } catch (e) {
          // Fallback to just computing the hash if metadata extraction fails
          // Get file bytes directly from the result
          Uint8List? fileBytes;
          if (result.files.single.bytes != null) {
            fileBytes = result.files.single.bytes!;
          } else if (result.files.single.path != null) {
            final file = File(result.files.single.path!);
            fileBytes = await file.readAsBytes();
          } else {
            throw Exception('Could not read file content');
          }

          if (fileBytes != null) {
            final digest = sha256.convert(fileBytes);
            setState(() {
              _fileHash = '0x${digest.toString()}';
            });
            
            // Add to audit trail
            _addToAuditTrail('FILE_HASH_COMPUTED', {
              'fileName': result.files.single.name,
              'hash': _fileHash
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: ${e.toString()}';
      });
      
      // Add to audit trail
      _addToAuditTrail('ERROR', {
        'action': 'FILE_PICK',
        'error': e.toString()
      });
    }
  }

  void _addToAuditTrail(String action, Map<String, dynamic> data) {
    setState(() {
      _auditTrail.add({
        'timestamp': DateTime.now().toIso8601String(),
        'action': action,
        'walletAddress': _walletAddress.isNotEmpty ? _walletAddress : 'Not connected',
        'data': data
      });
    });
  }

  // Helper method to get chain ID based on RPC URL
  int _getChainId() {
    if (_rpcUrl.contains('127.0.0.1') || _rpcUrl.contains('localhost')) {
      return 1337; // Default Ganache chain ID
    } else if (_rpcUrl.contains('sepolia')) {
      return 11155111; // Sepolia chain ID
    } else {
      return 1; // Default to Ethereum mainnet
    }
  }

  Future<void> _registerDocument() async {
    if (_fileHash.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Remove '0x' prefix if present to prevent double prefixing
      final cleanPrivateKey = _privateKey.startsWith('0x')
          ? _privateKey.substring(2)
          : _privateKey;

      final credentials = EthPrivateKey.fromHex(cleanPrivateKey);

      // Convert string hash to bytes32
      final registerFunction = _contract!.function('registerDocument');

      // Convert hash from hex string to bytes32
      final hashBytes = hexToBytes(_fileHash);

      // Get the appropriate chain ID based on the RPC URL
      final chainId = _getChainId();

      // Create metadata JSON to store on-chain
      String metadataJson = '';
      
      if (_documentMetadata != null) {
        metadataJson = _documentMetadata!.toJsonString();
      } else {
        // Create basic metadata if extraction didn't work
        final basicMetadata = {
          'fileName': _selectedFile?.files.single.name ?? 'Unknown',
          'fileSize': _selectedFile?.files.single.size.toString() ?? 'Unknown',
          'registeredAt': DateTime.now().toIso8601String(),
          'registeredBy': _walletAddress,
        };
        metadataJson = jsonEncode(basicMetadata);
      }

      _addToAuditTrail('REGISTER_DOCUMENT_ATTEMPT', {
        'hash': _fileHash,
        'metadata': metadataJson.substring(0, metadataJson.length > 100 ? 100 : metadataJson.length) + '...',
        'chainId': chainId,
      });

      final result = await _ethClient!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract!,
          function: registerFunction,
          parameters: [hashBytes, metadataJson],
        ),
        chainId: chainId,
      );

      _addToAuditTrail('DOCUMENT_REGISTERED', {
        'hash': _fileHash,
        'txHash': result,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document registered successfully. Transaction: ${result.substring(0, 10)}...')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error registering document: ${e.toString()}';
      });
      
      _addToAuditTrail('REGISTER_DOCUMENT_ERROR', {
        'hash': _fileHash,
        'error': e.toString(),
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyDocument() async {
    if (_fileHash.isEmpty) {
      setState(() {
        _errorMessage = 'Please select a file first';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert hash from hex string to bytes32
      final hashBytes = hexToBytes(_fileHash);

      _addToAuditTrail('VERIFY_DOCUMENT_ATTEMPT', {
        'hash': _fileHash,
      });

      // Use the correct function name from the updated ABI
      final getDocumentFunction = _contract!.function('getDocumentInfo');

      final response = await _ethClient!.call(
        contract: _contract!,
        function: getDocumentFunction,
        params: [hashBytes],
      );

      _addToAuditTrail('DOCUMENT_VERIFIED', {
        'hash': _fileHash,
        'found': true,
        'status': _getStatusString(response[2]),
      });

      // Parse status to user-friendly string
      final statusString = _getStatusString(response[2]);
      final statusColor = _getStatusColor(response[2]);
      final statusCode = response[2] is BigInt ? (response[2] as BigInt).toInt() : response[2] as int;
      
      // Parse metadata
      String metadataJson = response[0];
      Map<String, dynamic> metadata = {};
      
      try {
        if (metadataJson.isNotEmpty) {
          metadata = jsonDecode(metadataJson);
        }
      } catch (e) {
        // If we can't parse the metadata, just use the raw string
        metadata = {'raw': metadataJson};
      }
      
      // Format timestamp
      String timestamp = '';
      try {
        final timestampInt = (response[3] as BigInt).toInt() * 1000;
        final date = DateTime.fromMillisecondsSinceEpoch(timestampInt);
        timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
      } catch (e) {
        timestamp = response[3].toString();
      }
      
      // Check if user is authorized verifier
      final isAuthorizedVerifier = await _isAuthorizedVerifier();

      // Show detailed verification dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[850],
          title: const Text(
            'Document Verification',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Status: ',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusString,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Owner:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  '${(response[1] as EthereumAddress).hex}',
                  style: TextStyle(fontFamily: 'monospace', color: Colors.white70),
                ),
                const SizedBox(height: 16),
                Text(
                  'Metadata:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildMetadataWidgets(metadata),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Timestamp:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  timestamp,
                  style: TextStyle(color: Colors.white70),
                ),
                // Check for verification audit
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: _getVerifierCount(hashBytes),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircularProgressIndicator();
                    }
                    
                    if (snapshot.hasError || !snapshot.hasData) {
                      return Text(
                        'Could not load verification audit trail',
                        style: TextStyle(color: Colors.red),
                      );
                    }
                    
                    final verifierCount = snapshot.data!;
                    
                    if (verifierCount == 0) {
                      return Text(
                        'No verifications recorded yet',
                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
                      );
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Trail:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '$verifierCount address(es) have verified this document',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
                
                // Add status update UI for authorized verifiers
                if (isAuthorizedVerifier && statusCode == 0) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Update Document Status:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _updateDocumentStatus(hashBytes, 1); // 1 = Verified
                        },
                        icon: Icon(Icons.check_circle, color: Colors.white),
                        label: Text('Verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _updateDocumentStatus(hashBytes, 2); // 2 = Rejected
                        },
                        icon: Icon(Icons.cancel, color: Colors.white),
                        label: Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
                
                // Show message if already verified or rejected
                if (isAuthorizedVerifier && statusCode > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusCode == 1 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          statusCode == 1 ? Icons.check_circle : Icons.cancel,
                          color: statusCode == 1 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This document has already been ${statusCode == 1 ? 'verified' : 'rejected'}',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Show message for non-verifiers
                if (!isAuthorizedVerifier) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You are not authorized to change document status',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying document: ${e.toString()}';
      });
      
      _addToAuditTrail('VERIFY_DOCUMENT_ERROR', {
        'hash': _fileHash,
        'error': e.toString(),
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  String _getStatusString(dynamic status) {
    if (status is BigInt) {
      switch (status.toInt()) {
        case 0:
          return 'Pending';
        case 1:
          return 'Verified';
        case 2:
          return 'Rejected';
        default:
          return 'Unknown';
      }
    } else if (status is int) {
      switch (status) {
        case 0:
          return 'Pending';
        case 1:
          return 'Verified';
        case 2:
          return 'Rejected';
        default:
          return 'Unknown';
      }
    }
    return 'Unknown';
  }
  
  Color _getStatusColor(dynamic status) {
    int statusCode = -1;
    
    if (status is BigInt) {
      statusCode = status.toInt();
    } else if (status is int) {
      statusCode = status;
    }
    
    switch (statusCode) {
      case 0:
        return Colors.orange; // Pending
      case 1:
        return Colors.green; // Verified
      case 2:
        return Colors.red; // Rejected
      default:
        return Colors.grey; // Unknown
    }
  }
  
  List<Widget> _buildMetadataWidgets(Map<String, dynamic> metadata) {
    List<Widget> widgets = [];
    
    metadata.forEach((key, value) {
      // If value is a nested object, format it properly
      var displayValue = value;
      if (value is Map) {
        displayValue = json.encode(value);
      } else if (value is List) {
        displayValue = json.encode(value);
      }
      
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$key: ',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[200]),
              ),
              Expanded(
                child: Text(
                  '$displayValue',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    });
    
    if (widgets.isEmpty) {
      widgets.add(
        Text(
          'No metadata available',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70),
        ),
      );
    }
    
    return widgets;
  }
  
  // Helper function to convert hex string to bytes32
  Uint8List hexToBytes(String hex) {
    // Remove '0x' prefix if present
    hex = hex.startsWith('0x') ? hex.substring(2) : hex;

    // Ensure 64 characters (32 bytes) by padding with zeros if needed
    hex = hex.padLeft(64, '0');

    // Convert to bytes
    List<int> result = [];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }

    return Uint8List.fromList(result);
  }

  Future<int> _getVerifierCount(Uint8List hashBytes) async {
    try {
      final countFunction = _contract!.function('getVerifierCount');
      final result = await _ethClient!.call(
        contract: _contract!,
        function: countFunction,
        params: [hashBytes],
      );
      
      if (result.isNotEmpty && result[0] is BigInt) {
        return (result[0] as BigInt).toInt();
      }
      return 0;
    } catch (e) {
      print('Error getting verifier count: $e');
      return 0;
    }
  }

  // Add function to check if user is authorized verifier
  Future<bool> _isAuthorizedVerifier() async {
    if (!_isConnected || _ethClient == null || _contract == null) {
      return false;
    }
    
    try {
      // Get current wallet address as EthereumAddress
      final walletAddress = EthereumAddress.fromHex(_walletAddress);
      
      // Call the authorized verifiers mapping
      final verifierFunction = _contract!.function('authorizedVerifiers');
      final response = await _ethClient!.call(
        contract: _contract!,
        function: verifierFunction,
        params: [walletAddress],
      );
      
      // Also check if the current user is the contract owner
      final ownerFunction = _contract!.function('owner');
      final ownerResponse = await _ethClient!.call(
        contract: _contract!,
        function: ownerFunction,
        params: [],
      );
      
      final isOwner = (ownerResponse[0] as EthereumAddress).hex.toLowerCase() == _walletAddress.toLowerCase();
      
      // Return true if user is either owner or authorized verifier
      return isOwner || (response[0] as bool);
    } catch (e) {
      print('Error checking verifier status: $e');
      return false;
    }
  }
  
  // Add function to update document status
  Future<void> _updateDocumentStatus(Uint8List hashBytes, int newStatus) async {
    setState(() => _isLoading = true);
    
    try {
      // Remove '0x' prefix if present to prevent double prefixing
      final cleanPrivateKey = _privateKey.startsWith('0x')
          ? _privateKey.substring(2)
          : _privateKey;
      
      final credentials = EthPrivateKey.fromHex(cleanPrivateKey);
      
      // Call updateDocumentStatus function from contract
      final updateFunction = _contract!.function('updateDocumentStatus');
      
      // Get the appropriate chain ID based on the RPC URL
      final chainId = _getChainId();
      
      _addToAuditTrail('UPDATE_DOCUMENT_STATUS_ATTEMPT', {
        'hash': _fileHash,
        'newStatus': newStatus == 1 ? 'Verified' : 'Rejected',
      });
      
      final result = await _ethClient!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract!,
          function: updateFunction,
          parameters: [hashBytes, BigInt.from(newStatus)],
        ),
        chainId: chainId,
      );
      
      _addToAuditTrail('DOCUMENT_STATUS_UPDATED', {
        'hash': _fileHash,
        'newStatus': newStatus == 1 ? 'Verified' : 'Rejected',
        'txHash': result,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document ${newStatus == 1 ? 'verified' : 'rejected'} successfully!'),
          backgroundColor: newStatus == 1 ? Colors.green : Colors.red,
        ),
      );
      
      // Re-verify document to show updated status
      _verifyDocument();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error updating document status: ${e.toString()}';
      });
      
      _addToAuditTrail('UPDATE_DOCUMENT_STATUS_ERROR', {
        'hash': _fileHash,
        'newStatus': newStatus == 1 ? 'Verified' : 'Rejected',
        'error': e.toString(),
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildWalletForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connect Your Wallet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Network Preset',
                      border: OutlineInputBorder(),
                    ),
                    value: null,
                    hint: const Text('Select Network'),
                    items: const [
                      DropdownMenuItem(
                        value: 'ganache',
                        child: Text('Ganache (Local)'),
                      ),
                      DropdownMenuItem(
                        value: 'sepolia',
                        child: Text('Sepolia Testnet'),
                      ),
                    ],
                    onChanged: !_isConnected
                        ? (value) {
                      if (value == 'ganache') {
                        setState(() {
                          _rpcUrl = 'http://127.0.0.1:7545'; // Ganache default
                          _contractAddress = dotenv.env['GANACHE_CONTRACT_ADDRESS'] ?? '';
                        });
                      } else if (value == 'sepolia') {
                        final infuraApiKey = dotenv.env['INFURA_API_KEY'] ?? '';
                        setState(() {
                          _rpcUrl = 'https://sepolia.infura.io/v3/$infuraApiKey';
                          _contractAddress = dotenv.env['CONTRACT_ADDRESS'] ?? '';
                        });
                      }
                    }
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Contract Address',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _contractAddress = value),
              controller: TextEditingController(text: _contractAddress),
              enabled: !_isConnected,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'RPC URL',
                hintText: 'http://127.0.0.1:7545 (Ganache) or https://sepolia.infura.io/v3/YOUR_API_KEY',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _rpcUrl = value),
              controller: TextEditingController(text: _rpcUrl),
              enabled: !_isConnected,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Wallet Address',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _walletAddress = value),
              enabled: !_isConnected,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Private Key',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _privateKey = value),
              obscureText: true,
              enabled: !_isConnected,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected ? _disconnectWallet : _setupWeb3,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? Colors.red : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(_isConnected ? 'Disconnect Wallet' : 'Connect Wallet'),
                  ),
                ),
              ],
            ),
            if (_isConnected) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connected: ${_walletAddress.substring(0, 6)}...${_walletAddress.substring(_walletAddress.length - 4)}',
                        style: TextStyle(color: Colors.green.shade800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterDocumentTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Register Document',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Wallet connection form
            if (!_isConnected) _buildWalletForm(),

            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFile != null
                                ? 'Selected: ${_selectedFile!.files.single.name}'
                                : 'No file selected',
                            style: TextStyle(
                              color: _selectedFile != null ? Colors.green : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select File'),
                        ),
                      ],
                    ),
                    if (_fileHash.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Document Hash:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _fileHash,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _fileHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hash copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnected && _fileHash.isNotEmpty
                            ? _registerDocument
                            : null,
                        icon: const Icon(Icons.add_to_photos),
                        label: const Text('Register Document'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (!_isConnected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Connect your wallet to register documents',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyDocumentTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verify Document',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Wallet connection form
            if (!_isConnected) _buildWalletForm(),

            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFile != null
                                ? 'Selected: ${_selectedFile!.files.single.name}'
                                : 'No file selected',
                            style: TextStyle(
                              color: _selectedFile != null ? Colors.green : Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _pickFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Select File'),
                        ),
                      ],
                    ),
                    if (_fileHash.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Document Hash:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _fileHash,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _fileHash));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hash copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnected && _fileHash.isNotEmpty ? _verifyDocument : null,
                        icon: const Icon(Icons.verified),
                        label: const Text('Verify Document'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    if (!_isConnected) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Connect your wallet to verify documents',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About the Platform',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Verification Platform',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This decentralized application allows users to securely register and verify digital documents on the blockchain. The platform operates on the Ethereum network and provides a tamper-proof, immutable record of document authenticity.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'How it works:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Register a document by uploading it and providing metadata\n'
                          '2. The document\'s cryptographic hash is stored on the blockchain\n'
                          '3. Authorized verifiers can validate document authenticity\n'
                          '4. Anyone can verify a document\'s status by checking its hash',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Technology Stack:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Ethereum Blockchain\n'
                          '• Solidity Smart Contracts\n'
                          '• Hardhat Development Environment\n'
                          '• Infura & Ganache for Network Access\n'
                          '• Flutter for Cross-Platform UI',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    if (!_isConnected) ...[
                      const Text(
                        'Getting Started:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Connect your Ethereum wallet with the Connect button\n'
                            '2. Select a document to register or verify\n'
                            '3. Submit the transaction to interact with the blockchain',
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Connecting to Ganache:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Start Ganache (UI or CLI version) on your machine\n'
                          '2. Deploy the DocumentVerification.sol contract using Hardhat or Truffle\n'
                          '3. Copy the contract address and update the GANACHE_CONTRACT_ADDRESS in .env\n'
                          '4. Select "Ganache (Local)" from the network dropdown\n'
                          '5. Copy a private key from Ganache\'s accounts list\n'
                          '6. Connect using the private key and the corresponding account address',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Supported Wallets:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• MetaMask - Browser extension & mobile app\n'
                          '• Trust Wallet - Mobile wallet with DApp browser\n'
                          '• Coinbase Wallet - User-friendly mobile wallet\n'
                          '• Direct Connection - Use account private key (as shown in the app)',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Verification Platform'),
        actions: [
          if (_isConnected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet, size: 16, color: Colors.green.shade800),
                    const SizedBox(width: 4),
                    Text(
                      '${_walletAddress.substring(0, 6)}...${_walletAddress.substring(_walletAddress.length - 4)}',
                      style: TextStyle(color: Colors.green.shade800),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_to_photos), text: 'Register'),
            Tab(icon: Icon(Icons.verified), text: 'Verify'),
            Tab(icon: Icon(Icons.info), text: 'About'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRegisterDocumentTab(),
                _buildVerifyDocumentTab(),
                _buildAboutTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
//hey