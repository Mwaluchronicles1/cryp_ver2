// This service has been temporarily disabled because we've removed the WalletConnect 
// dependencies to fix build issues. When you're ready to re-enable WalletConnect,
// you can reinstall the dependencies and remove this comment.

/*
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_secure_storage/walletconnect_secure_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';

class WalletConnectService {
  static final WalletConnectService _instance = WalletConnectService._internal();
  factory WalletConnectService() => _instance;
  WalletConnectService._internal();

  WalletConnect? _connector;
  SessionStatus? _sessionStatus;
  Web3Client? _web3client;

  bool get isConnected => _sessionStatus?.connected ?? false;
  String get walletAddress => _sessionStatus?.accounts.first ?? '';

  Future<void> init() async {
    _connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: PeerMeta(
        name: 'Document Verification dApp',
        description: 'A dApp for verifying document authenticity',
        url: 'https://yourappwebsite.com',
        icons: ['https://your-app-icon.png'],
      ),
      storage: WalletConnectSecureStorage(),
    );

    _connector!.on('connect', (session) {
      _sessionStatus = session as SessionStatus;
      _setupWeb3();
    });

    _connector!.on('session_update', (payload) {
      _sessionStatus = payload as SessionStatus;
    });

    _connector!.on('disconnect', (payload) {
      _sessionStatus = null;
      _web3client = null;
    });
  }

  Future<bool> connect(BuildContext context) async {
    if (_connector == null) await init();

    if (!_connector!.connected) {
      try {
        _sessionStatus = await _connector!.createSession(
          onDisplayUri: (uri) => _displayQRCode(context, uri),
        );
        return true;
      } catch (e) {
        print('Error connecting: $e');
        return false;
      }
    }
    return false;
  }

  Future<void> disconnect() async {
    if (_connector?.connected == true) {
      await _connector!.killSession();
    }
    _sessionStatus = null;
  }

  void _setupWeb3() {
    if (_sessionStatus?.chainId == 1) {
      _web3client = Web3Client('https://mainnet.infura.io/v3/your-project-id', Client());
    } else if (_sessionStatus?.chainId == 5) {
      _web3client = Web3Client('https://goerli.infura.io/v3/your-project-id', Client());
    } else if (_sessionStatus?.chainId == 1337) {
      _web3client = Web3Client('http://127.0.0.1:7545', Client());
    }
  }

  void _displayQRCode(BuildContext context, String uri) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Connect your wallet'),
          content: SizedBox(
            width: 300,
            height: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Scan QR code with your wallet app'),
                const SizedBox(height: 20),
                QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 250,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
          ],
        );
      },
    );
  }

  Future<String> registerDocument(String contractAddress, String documentHash, String metadataUrl) async {
    if (_web3client == null || _sessionStatus == null) {
      throw Exception('Wallet not connected');
    }

    // Load contract ABI (you'll need to create this)
    final contractABI = ContractAbi.fromJson('yourContractABI', 'DocumentVerification');
    final contract = DeployedContract(
      contractABI,
      EthereumAddress.fromHex(contractAddress),
    );

    final function = contract.function('registerDocument');
    final credentials = WalletConnectEthereumCredentials(connector: _connector!);

    final transaction = Transaction.callContract(
      contract: contract,
      function: function,
      parameters: [
        hexToBytes(documentHash),
        metadataUrl,
      ],
    );

    return await _web3client!.sendTransaction(credentials, transaction);
  }

  Future<Map<String, dynamic>> getDocumentStatus(String contractAddress, String documentHash) async {
    if (_web3client == null) {
      throw Exception('Wallet not connected');
    }

    // Load contract ABI (you'll need to create this)
    final contractABI = ContractAbi.fromJson('yourContractABI', 'DocumentVerification');
    final contract = DeployedContract(
      contractABI,
      EthereumAddress.fromHex(contractAddress),
    );

    final function = contract.function('getDocumentInfo');
    final result = await _web3client!.call(
      contract: contract,
      function: function,
      params: [hexToBytes(documentHash)],
    );

    if (result.isEmpty) {
      throw Exception('Document not found');
    }

    return {
      'metadataURI': result[0],
      'owner': (result[1] as EthereumAddress).hex,
      'status': result[2],
      'timestamp': result[3],
    };
  }
}

class WalletConnectEthereumCredentials extends CustomTransactionSender {
  WalletConnectEthereumCredentials({required this.connector});

  final WalletConnect connector;

  @override
  Future<EthereumAddress> extractAddress() async {
    final account = connector.session.accounts[0];
    return EthereumAddress.fromHex(account);
  }

  @override
  Future<String> sendTransaction(Transaction transaction) async {
    final from = await extractAddress();
    final gasPrice = transaction.gasPrice?.getInWei;
    final maxGas = transaction.maxGas;
    final value = transaction.value?.getInWei;
    final data = transaction.data;

    final txRequest = {
      'from': from.hex,
      if (transaction.to != null) 'to': transaction.to!.hex,
      if (maxGas != null) 'gas': '0x${maxGas.toRadixString(16)}',
      if (gasPrice != null) 'gasPrice': '0x${gasPrice.toRadixString(16)}',
      if (value != null) 'value': '0x${value.toRadixString(16)}',
      if (data != null) 'data': '0x${bytesToHex(data)}',
    };

    return await connector.sendTransaction(txRequest);
  }

  @override
  Future<String> signToEcSignature(Uint8List payload, {int? chainId, bool isEIP1559 = false}) {
    throw UnimplementedError('signToEcSignature not implemented for WalletConnect');
  }
}
*/ 