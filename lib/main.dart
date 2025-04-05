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
  String _metadataUrl = '';

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
        });

        // Compute file hash from bytes (works on all platforms including web)
        Uint8List? fileBytes;

        // Get file bytes directly from the result
        if (result.files.single.bytes != null) {
          // Web platform will use this branch
          fileBytes = result.files.single.bytes!;
        } else if (result.files.single.path != null) {
          // Native platforms can use this as fallback
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
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: ${e.toString()}';
      });
    }
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

      // Use empty string for metadata instead of _metadataUrl
      final result = await _ethClient!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: _contract!,
          function: registerFunction,
          parameters: [hashBytes, ''], // Empty string instead of _metadataUrl
        ),
        chainId: chainId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Document registered successfully. Transaction: ${result.substring(0, 10)}...')),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error registering document: ${e.toString()}';
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

      // Use the correct function name from the updated ABI
      final getDocumentFunction = _contract!.function('getDocumentInfo');

      final response = await _ethClient!.call(
        contract: _contract!,
        function: getDocumentFunction,
        params: [hashBytes],
      );

      if (response.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document not found or not registered')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Convert status code to text
      String statusText = 'Unknown';
      switch (response[2].toInt()) {
        case 0:
          statusText = 'Pending';
          break;
        case 1:
          statusText = 'Verified';
          break;
        case 2:
          statusText = 'Rejected';
          break;
      }

      // Show document info
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Document Verification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $statusText'),
                const SizedBox(height: 8),
                Text('Owner: ', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  '${response[1].toString()}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text('Metadata: ', style: TextStyle(fontWeight: FontWeight.bold)),
                SelectableText(
                  '${response[0]}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamp: ${DateTime.fromMillisecondsSinceEpoch((response[3] as BigInt).toInt() * 1000).toString()}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error verifying document: ${e.toString()}';
      });
    } finally {
      setState(() => _isLoading = false);
    }
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