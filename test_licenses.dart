import 'dart:convert';
import 'package:crypto/crypto.dart';

void main() {
  const salt = "QB2024";
  final inputs = [
    'LICENSE1',
    'LICENSE2',
    'LICENSE3',
    'TEST001',
    'TEST002',
    'PROD001',
    'PROD002',
    'PROD003',
  ];

  for (final input in inputs) {
    final bytes = utf8.encode(input + salt);
    final digest = sha256.convert(bytes);
    final hash = digest.toString().substring(0, 10).toUpperCase();
    print('QRBARCODE-$hash (from $input)');
  }
}
