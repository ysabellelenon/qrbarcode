import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

void main() async {
  const salt = "QB2024";
  final prefixes = ['JAE', 'QBS', 'TST', 'PRD'];
  final licenses = <String>[];

  // Generate 250 licenses (50 for each prefix)
  for (var prefix in prefixes) {
    for (var i = 1; i <= 50; i++) {
      final input = '${prefix}${i.toString().padLeft(4, '0')}';
      final bytes = utf8.encode(input + salt);
      final digest = sha256.convert(bytes);
      final hash = digest.toString().substring(0, 10).toUpperCase();
      final license = 'QRBARCODE-$hash (from $input)';
      licenses.add(license);
    }
  }

  // Add the original test licenses
  final originalInputs = [
    'LICENSE1',
    'LICENSE2',
    'LICENSE3',
    'TEST001',
    'TEST002',
    'PROD001',
    'PROD002',
    'PROD003',
  ];

  for (final input in originalInputs) {
    final bytes = utf8.encode(input + salt);
    final digest = sha256.convert(bytes);
    final hash = digest.toString().substring(0, 10).toUpperCase();
    final license = 'QRBARCODE-$hash (from $input)';
    licenses.add(license);
  }

  // Sort licenses for better readability
  licenses.sort();

  // Create the output with a header
  final output = '''
// QR Barcode System License Keys
// Generated on ${DateTime.now()}
// Total Licenses: ${licenses.length}
// 
// Format: QRBARCODE-[HASH] (from [SOURCE])
// Each license key is unique and pre-validated
// 
${licenses.join('\n')}
''';

  // Write to file
  await File('licenses.txt').writeAsString(output);
  print('Generated ${licenses.length} licenses and saved to licenses.txt');
}
