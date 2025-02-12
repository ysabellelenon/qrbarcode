import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database_helper.dart';
import 'package:sqflite/sqflite.dart';

class LicenseService {
  static LicenseService? _instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // This salt will be compiled into the binary
  static const String _salt = "QB2024"; 
  

  // All valid license keys hardcoded
  static const List<String> _validLicenses = [
    'QRBARCODE-017B661D50',
    'QRBARCODE-01A8CA8171',
    'QRBARCODE-036BC7BF3E',
    'QRBARCODE-04ECC51D3C',
    'QRBARCODE-0536C69DCA',
    'QRBARCODE-0555C17E5F',
    'QRBARCODE-05AFCC12D0',
    'QRBARCODE-062DAF407B',
    'QRBARCODE-08751F8568',
    'QRBARCODE-088C64CCCA',
    'QRBARCODE-08A78FE622',
    'QRBARCODE-0A3499589A',
    'QRBARCODE-0A5FEF92AD',
    'QRBARCODE-0BC4496270',
    'QRBARCODE-0C10DA40C8',
    'QRBARCODE-0DE77A5372',
    'QRBARCODE-0E04AD7866',
    'QRBARCODE-0E51348C00',
    'QRBARCODE-0E680F7404',
    'QRBARCODE-0F28BF275F',
    'QRBARCODE-0F44B9E3B2',
    'QRBARCODE-0FB841F1D3',
    'QRBARCODE-11C558F2A5',
    'QRBARCODE-12A25843B6',
    'QRBARCODE-13613B04CF',
    'QRBARCODE-153AECBC82',
    'QRBARCODE-1A43C2E1F2',
    'QRBARCODE-1D2A1A29F8',
    'QRBARCODE-1E5E0B1965',
    'QRBARCODE-1E773CF7F3',
    'QRBARCODE-1F269717FC',
    'QRBARCODE-1FC53A5CAE',
    'QRBARCODE-22F64432B7',
    'QRBARCODE-23D7908B60',
    'QRBARCODE-27069AB8F1',
    'QRBARCODE-27443A1EEE',
    'QRBARCODE-2772024408',
    'QRBARCODE-2793900186',
    'QRBARCODE-27FEF756D3',
    'QRBARCODE-2983394702',
    'QRBARCODE-29C156CA49',
    'QRBARCODE-2A4C48D904',
    'QRBARCODE-2AD6C4954E',
    'QRBARCODE-2B48499BF6',
    'QRBARCODE-2B71372350',
    'QRBARCODE-2BB1611687',
    'QRBARCODE-2CAC71E019',
    'QRBARCODE-2E87915749',
    'QRBARCODE-2E99F04608',
    'QRBARCODE-2ED7DB1579',
    'QRBARCODE-2F55CA7535',
    'QRBARCODE-2FA65670EC',
    'QRBARCODE-34CF8E0C48',
    'QRBARCODE-36249545A6',
    'QRBARCODE-3A7997970B',
    'QRBARCODE-3C96A705D0',
    'QRBARCODE-3D548AF469',
    'QRBARCODE-3E6780834F',
    'QRBARCODE-44B8C83368',
    'QRBARCODE-45536E63AF',
    'QRBARCODE-45669F219A',
    'QRBARCODE-46122410D9',
    'QRBARCODE-46DE21C6B0',
    'QRBARCODE-473E7F5327',
    'QRBARCODE-481CA58685',
    'QRBARCODE-49ED13DA97',
    'QRBARCODE-4A8AA12C1C',
    'QRBARCODE-4C495BE703',
    'QRBARCODE-4D86F1EB20',
    'QRBARCODE-4DD9C5991C',
    'QRBARCODE-4EE57AE2A8',
    'QRBARCODE-5039E1BF69',
    'QRBARCODE-50BA885B6E',
    'QRBARCODE-55ED7DE2AE',
    'QRBARCODE-566C708974',
    'QRBARCODE-5692757931',
    'QRBARCODE-57D4EEB9C4',
    'QRBARCODE-58B27FFB05',
    'QRBARCODE-5A333849F0',
    'QRBARCODE-5ADFDF2E69',
    'QRBARCODE-5B01309086',
    'QRBARCODE-5B9B3F3C8F',
    'QRBARCODE-5D52144209',
    'QRBARCODE-5D9CAD75EA',
    'QRBARCODE-5E23F22162',
    'QRBARCODE-60659D01F1',
    'QRBARCODE-60B823897F',
    'QRBARCODE-60B9B6448B',
    'QRBARCODE-628417ED53',
    'QRBARCODE-63CE211AF5',
    'QRBARCODE-6746425763',
    'QRBARCODE-67A410CE91',
    'QRBARCODE-685DBC43A4',
    'QRBARCODE-6C52BDC129',
    'QRBARCODE-6D79106D55',
    'QRBARCODE-6F1E8A19F3',
    'QRBARCODE-701042C3CF',
    'QRBARCODE-7524388D76',
    'QRBARCODE-765CB8C53C',
    'QRBARCODE-7A133AEC51',
    'QRBARCODE-7BD6D9C4BA',
    'QRBARCODE-7C02E9724D',
    'QRBARCODE-7D52057B92',
    'QRBARCODE-7E554A663A',
    'QRBARCODE-7F3C2D6909',
    'QRBARCODE-81F52B2D67',
    'QRBARCODE-8310F2DD73',
    'QRBARCODE-833FBF00F7',
    'QRBARCODE-8349B84491',
    'QRBARCODE-83B6A92953',
    'QRBARCODE-85EAE81F15',
    'QRBARCODE-86499E4EF6',
    'QRBARCODE-870B5AD9FF',
    'QRBARCODE-880DD7A66C',
    'QRBARCODE-8B311F09FB',
    'QRBARCODE-8C5C993A36',
    'QRBARCODE-8D706ED0E2',
    'QRBARCODE-8E588E3596',
    'QRBARCODE-9105E67F01',
    'QRBARCODE-91083140A1',
    'QRBARCODE-9249B55C57',
    'QRBARCODE-9551BA533A',
    'QRBARCODE-986219A27E',
    'QRBARCODE-9A7D5D5D0B',
    'QRBARCODE-9C0DBC7147',
    'QRBARCODE-9E7E57BFF9',
    'QRBARCODE-9EA6873859',
    'QRBARCODE-9F0677E122',
    'QRBARCODE-9F1699DC40',
    'QRBARCODE-A14401B78A',
    'QRBARCODE-A35C193F89',
    'QRBARCODE-A3C278B590',
    'QRBARCODE-A41F5D28EC',
    'QRBARCODE-A44BDC89B8',
    'QRBARCODE-A50C9D8953',
    'QRBARCODE-A9D8F427B5',
    'QRBARCODE-ABA51D906A',
    'QRBARCODE-ADF3B3DF7D',
    'QRBARCODE-B02A9F291C',
    'QRBARCODE-B26D1CEFDC',
    'QRBARCODE-B39D9DAB79',
    'QRBARCODE-B3A6C9BD6D',
    'QRBARCODE-B3F9A923B9',
    'QRBARCODE-B474A8C7D3',
    'QRBARCODE-B4A3CD6848',
    'QRBARCODE-B51F932AFD',
    'QRBARCODE-B5AF3A05EC',
    'QRBARCODE-B6AB598F4E',
    'QRBARCODE-B931AD33F6',
    'QRBARCODE-BA25B5E979',
    'QRBARCODE-BC1A886455',
    'QRBARCODE-BE1FDAEE7B',
    'QRBARCODE-BEB5A170A7',
    'QRBARCODE-BEB7DB7C58',
    'QRBARCODE-BF32476768',
    'QRBARCODE-BF4D405D23',
    'QRBARCODE-C03E82C23D',
    'QRBARCODE-C23F5FF48F',
    'QRBARCODE-C4C404754D',
    'QRBARCODE-C79C6D81E6',
    'QRBARCODE-C8BFD5E9D3',
    'QRBARCODE-C8C1D28A1C',
    'QRBARCODE-CA1A315B11',
    'QRBARCODE-CAD7ED7F8E',
    'QRBARCODE-CD99E29284',
    'QRBARCODE-CDE1169FF1',
    'QRBARCODE-D0025ECF84',
    'QRBARCODE-D26D0CE749',
    'QRBARCODE-D3777D9760',
    'QRBARCODE-D4E49476D1',
    'QRBARCODE-D4FF642D02',
    'QRBARCODE-D5A5A39222',
    'QRBARCODE-D5B26B1CD5',
    'QRBARCODE-D96BA9BC8F',
    'QRBARCODE-DA5C3848BA',
    'QRBARCODE-DCEA54EAB5',
    'QRBARCODE-DD21457D11',
    'QRBARCODE-DF0B0EC928',
    'QRBARCODE-DFB0A9D09E',
    'QRBARCODE-E003A7A422',
    'QRBARCODE-E210724F6E',
    'QRBARCODE-E322988B44',
    'QRBARCODE-E4ACB3495A',
    'QRBARCODE-E5D28A80B3',
    'QRBARCODE-E7BB941A5E',
    'QRBARCODE-EAFE9DAFB9',
    'QRBARCODE-EBBF243061',
    'QRBARCODE-EC724BCF8D',
    'QRBARCODE-ECFE6501DA',
    'QRBARCODE-ED09C3C15A',
    'QRBARCODE-EFAC4A3E2B',
    'QRBARCODE-F2E74DA943',
    'QRBARCODE-F30B5E3154',
    'QRBARCODE-F3D8EF35E4',
    'QRBARCODE-F3DC1FF083',
    'QRBARCODE-F4DB115585',
    'QRBARCODE-F4DE1734FA',
    'QRBARCODE-F61941CDF0',
    'QRBARCODE-F67AC4523C',
    'QRBARCODE-F6FDF88D97',
    'QRBARCODE-F72CC68D78',
    'QRBARCODE-F7C9A54E73',
    'QRBARCODE-F7F7DA36AB',
    'QRBARCODE-FA600DF939',
    'QRBARCODE-FCC3C00022',
    'QRBARCODE-FD71488BC1',
    'QRBARCODE-FE1E310633',
    'QRBARCODE-FEC8402AA9',
  ];

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
    
    // Check if the full license key exists in our valid licenses list
    final licenseKey = 'QRBARCODE-$hash';
    final isValid = _validLicenses.contains(licenseKey);
    print('🔑 License validation result: $isValid');
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
