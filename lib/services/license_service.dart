import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database_helper.dart';
import 'package:sqflite/sqflite.dart';

class LicenseService {
  static LicenseService? _instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // This salt will be compiled into the binary
  static const String _salt = "QB2024";

  LicenseService._();

  static Future<LicenseService> getInstance() async {
    print('🔑 Getting LicenseService instance');
    if (_instance == null) {
      _instance = LicenseService._();
    }
    return _instance!;
  }

  Future<bool> validateLicense(String licenseKey) async {
    try {
      print('🔑 Validating license: $licenseKey');
      print('🔑 License length: ${licenseKey.length}');

      // First check if it's already activated
      if (await _checkLocalLicense(licenseKey)) {
        print('✅ License already activated locally');
        return true;
      }

      // Validate format
      if (!licenseKey.startsWith('QRBARCODE-')) {
        print('❌ Invalid license prefix');
        return false;
      }

      // Get the hash part (skip 'QRBARCODE-')
      final hash =
          licenseKey.substring(10); // Changed from 9 to 10 to skip the hyphen
      print('🔑 Extracted hash: $hash');

      // Validate the hash using our validation logic
      if (_isValidHash(hash)) {
        print('✅ Valid license key');
        return true;
      }

      print('❌ Invalid license key');
      return false;
    } catch (e, stackTrace) {
      print('❌ Error validating license: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> activateLicense(String licenseKey) async {
    try {
      print('🔑 Starting license activation for key: $licenseKey');

      // Validate the license
      if (!await validateLicense(licenseKey)) {
        print('❌ License validation failed');
        return false;
      }

      // Save to local database
      await saveLicenseLocally(licenseKey);
      print('✅ License activation completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error activating license: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> _checkLocalLicense(String licenseKey) async {
    try {
      print('🔑 Checking local license');
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> result = await db.query(
        'license_info',
        where: 'license_key = ?',
        whereArgs: [licenseKey],
      );

      return result.isNotEmpty;
    } catch (e, stackTrace) {
      print('❌ Error checking local license: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> saveLicenseLocally(String licenseKey) async {
    try {
      print('🔑 Saving license locally: $licenseKey');
      final db = await _dbHelper.database;

      await db.insert(
        'license_info',
        {
          'license_key': licenseKey,
          'activated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ License saved successfully');
    } catch (e, stackTrace) {
      print('❌ Error saving license: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getStoredLicense() async {
    try {
      print('🔑 Getting stored license');
      final db = await _dbHelper.database;

      final List<Map<String, dynamic>> result = await db.query(
        'license_info',
        orderBy: 'activated_at DESC',
        limit: 1,
      );

      if (result.isNotEmpty) {
        final licenseKey = result.first['license_key'] as String;
        print('🔑 Retrieved stored license: $licenseKey');
        return licenseKey;
      }
      print('❌ No stored license found');
      return null;
    } catch (e, stackTrace) {
      print('❌ Error getting stored license: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> clearLicense() async {
    try {
      print('🔑 Clearing stored license');
      final db = await _dbHelper.database;
      await db.delete('license_info');
      print('✅ License cleared successfully');
    } catch (e, stackTrace) {
      print('❌ Error clearing license: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Validates a hash using a secure algorithm
  bool _isValidHash(String hash) {
    print('🔑 Validating hash: $hash');
    // List of valid hashes - these will be compiled into the binary
    // but will be more difficult to extract than plain text
    final validHashes = [
      _generateHash('LICENSE1'),
      _generateHash('LICENSE2'),
      _generateHash('LICENSE3'),
      _generateHash('TEST001'),
      _generateHash('TEST002'),
      _generateHash('PROD001'),
      _generateHash('PROD002'),
      _generateHash('PROD003'),
    ];

    print('🔑 Valid hashes: $validHashes');
    final isValid = validHashes.contains(hash);
    print('🔑 Hash validation result: $isValid');
    return isValid;
  }

  // Generate a hash for a license key
  String _generateHash(String input) {
    print('🔑 Generating hash for input: $input');
    final bytes = utf8.encode(input + _salt);
    final digest = sha256.convert(bytes);
    final hash = digest.toString().substring(0, 10).toUpperCase();
    print('🔑 Generated hash: $hash');
    return hash;
  }
}
