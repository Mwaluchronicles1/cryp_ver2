import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DocumentMetadata {
  final String fileName;
  final String fileType;
  final String fileSize;
  final String lastModified;
  final String hash;
  final Map<String, String> additionalMetadata;
  
  DocumentMetadata({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.lastModified,
    required this.hash,
    this.additionalMetadata = const {},
  });
  
  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'fileSize': fileSize,
      'lastModified': lastModified,
      'hash': hash,
      'additionalMetadata': additionalMetadata,
    };
  }
  
  String toJsonString() {
    return jsonEncode(toJson());
  }
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Document Metadata:');
    buffer.writeln('- File Name: $fileName');
    buffer.writeln('- File Type: $fileType');
    buffer.writeln('- File Size: $fileSize');
    buffer.writeln('- Last Modified: $lastModified');
    buffer.writeln('- Hash: $hash');
    
    if (additionalMetadata.isNotEmpty) {
      buffer.writeln('- Additional Metadata:');
      additionalMetadata.forEach((key, value) {
        buffer.writeln('  • $key: $value');
      });
    }
    
    return buffer.toString();
  }
}

class DocumentMetadataExtractor {
  static Future<DocumentMetadata> extractMetadata(FilePickerResult fileResult) async {
    final file = fileResult.files.single;
    final fileName = file.name;
    final fileExtension = path.extension(fileName).toLowerCase();
    final fileType = _getFileTypeDescription(fileExtension);
    
    // Format file size
    final fileSizeBytes = file.size;
    final fileSize = _formatFileSize(fileSizeBytes);
    
    // Get last modified date if available, otherwise use current time
    final DateTime lastModified = DateTime.now();
    
    // Get file bytes
    Uint8List? fileBytes;
    if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    } else {
      throw Exception('Could not read file content');
    }
    
    // Calculate hash
    final digest = sha256.convert(fileBytes);
    final hash = '0x${digest.toString()}';
    
    // Extract additional metadata based on file type
    final additionalMetadata = await _extractAdditionalMetadata(fileBytes, fileExtension, fileName);
    
    return DocumentMetadata(
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      lastModified: DateFormat('yyyy-MM-dd HH:mm:ss').format(lastModified),
      hash: hash,
      additionalMetadata: additionalMetadata,
    );
  }
  
  static String _getFileTypeDescription(String extension) {
    switch (extension) {
      case '.pdf':
        return 'PDF Document';
      case '.docx':
        return 'Microsoft Word Document';
      case '.xlsx':
        return 'Microsoft Excel Spreadsheet';
      case '.pptx':
        return 'Microsoft PowerPoint Presentation';
      case '.jpg':
      case '.jpeg':
        return 'JPEG Image';
      case '.png':
        return 'PNG Image';
      case '.txt':
        return 'Text Document';
      case '.md':
        return 'Markdown Document';
      case '.json':
        return 'JSON File';
      case '.xml':
        return 'XML Document';
      case '.csv':
        return 'CSV Spreadsheet';
      default:
        return 'Document (${extension.isEmpty ? "Unknown Type" : extension.substring(1)})';
    }
  }
  
  static String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }
  
  static Future<Map<String, String>> _extractAdditionalMetadata(
    Uint8List fileBytes, 
    String fileExtension,
    String fileName
  ) async {
    final metadata = <String, String>{};
    
    // Add creation timestamp
    metadata['createdAt'] = DateTime.now().toIso8601String();
    
    // Add basic structural metadata based on file type
    switch (fileExtension) {
      case '.pdf':
        metadata['docType'] = 'PDF Document';
        // Check for PDF header
        if (fileBytes.length > 5 && 
            String.fromCharCodes(fileBytes.sublist(0, 5)) == '%PDF-') {
          metadata['pdfVersion'] = String.fromCharCodes(fileBytes.sublist(5, 8));
        }
        break;
        
      case '.jpg':
      case '.jpeg':
      case '.png':
        metadata['docType'] = 'Image';
        // Extract image dimensions if possible
        // Note: This is a simplified approach. For a complete solution,
        // you'd use a proper image processing library
        try {
          if (fileExtension == '.png' && fileBytes.length > 24) {
            // PNG width is at bytes 16-19, height at 20-23
            final width = (fileBytes[16] << 24) | (fileBytes[17] << 16) | (fileBytes[18] << 8) | fileBytes[19];
            final height = (fileBytes[20] << 24) | (fileBytes[21] << 16) | (fileBytes[22] << 8) | fileBytes[23];
            metadata['dimensions'] = '${width}x${height}';
          }
        } catch (e) {
          // Silently fail if we can't extract image dimensions
        }
        break;
        
      case '.docx':
      case '.xlsx':
      case '.pptx':
        metadata['docType'] = 'Microsoft Office Document';
        break;
        
      case '.txt':
      case '.md':
        metadata['docType'] = 'Text Document';
        // Count words and lines for text documents
        try {
          final text = utf8.decode(fileBytes);
          final lines = text.split('\n').length;
          final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
          metadata['lines'] = lines.toString();
          metadata['words'] = words.toString();
        } catch (e) {
          // Silently fail if we can't decode text
        }
        break;
        
      default:
        metadata['docType'] = 'Generic Document';
    }
    
    // Extract filename components
    final name = path.basenameWithoutExtension(fileName);
    metadata['baseName'] = name;
    
    return metadata;
  }
} 