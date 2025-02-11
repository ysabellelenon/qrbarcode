import 'package:gsheets/gsheets.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import 'package:system_info2/system_info2.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const String _credentialsPath = 'assets/credentials.json';
  static const String _spreadsheetId =
      '16vpCNpvJ9rlVJqp4cxhq19P_Io0K3dslKTPQPk3iCL8';
  static const String _licenseKey = 'license_key';
  static const String _deviceId = 'device_id';

  static LicenseService? _instance;
  late final GSheets _gsheets;
  Spreadsheet? _spreadsheet;
  Worksheet? _worksheet;
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  LicenseService._();

  static Future<LicenseService> getInstance() async {
    print('🔑 Getting LicenseService instance');
    if (_instance == null) {
      _instance = LicenseService._();
      // Only initialize SharedPreferences, defer GSheets initialization
      await _instance!._initializePrefs();
    }
    return _instance!;
  }

  Future<void> _initializePrefs() async {
    try {
      print('🔑 Initializing SharedPreferences');
      _prefs = await SharedPreferences.getInstance();
      print('✅ SharedPreferences initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize SharedPreferences: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _initializeGSheets() async {
    if (_isInitialized) return;

    try {
      print('🔑 Initializing GSheets connection');
      print('🔑 Loading credentials from: $_credentialsPath');
      final credentials = await rootBundle.loadString(_credentialsPath);
      print('🔑 Credentials loaded successfully');

      _gsheets = GSheets(credentials);
      print('🔑 Connecting to spreadsheet: $_spreadsheetId');
      _spreadsheet = await _gsheets.spreadsheet(_spreadsheetId);
      print('🔑 Connected to spreadsheet successfully');

      print('🔑 Accessing worksheet: QRBarcode');
      _worksheet = _spreadsheet!.worksheetByTitle('QRBarcode') ??
          await _spreadsheet!.addWorksheet('QRBarcode');
      print('🔑 Worksheet accessed successfully');

      await _ensureHeaders();
      _isInitialized = true;
      print('🔑 GSheets connection initialized successfully');
    } catch (e, stackTrace) {
      print('❌ Failed to initialize GSheets connection: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _ensureHeaders() async {
    final headers = [
      'license',
      'type',
      'duration_days',
      'status',
      'used',
      'activation_date',
      'expiration_date',
      'machine_id',
      'notes'
    ];

    try {
      print('🔑 Checking worksheet headers');
      final existingHeaders = await _worksheet?.values.row(1);
      print('🔑 Existing headers: $existingHeaders');

      if (existingHeaders == null || existingHeaders.isEmpty) {
        print('🔑 Adding headers to worksheet');
        await _worksheet?.values.insertRow(1, headers);
        print('🔑 Headers added successfully');
      }
    } catch (e, stackTrace) {
      print('❌ Error ensuring headers: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String> getMachineId() async {
    try {
      String? storedDeviceId = _prefs.getString(_deviceId);
      if (storedDeviceId != null) {
        print('🔑 Retrieved stored machine ID: $storedDeviceId');
        return storedDeviceId;
      }

      print('🔑 Generating new machine ID');
      final kernelName = SysInfo.kernelName;
      final kernelVersion = SysInfo.kernelVersion;
      final operatingSystemName = SysInfo.operatingSystemName;

      print(
          '🔑 System info - Kernel: $kernelName, Version: $kernelVersion, OS: $operatingSystemName');

      final rawId = '$kernelName:$kernelVersion:$operatingSystemName';
      final bytes = utf8.encode(rawId);
      final hash = sha256.convert(bytes);
      final deviceId = hash.toString().substring(0, 16).toUpperCase();

      print('🔑 Generated machine ID: $deviceId');
      await _prefs.setString(_deviceId, deviceId);
      return deviceId;
    } catch (e, stackTrace) {
      print('❌ Error getting machine ID: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _getLicenseInfo(String licenseKey) async {
    try {
      if (_worksheet == null) throw Exception('Worksheet not initialized');

      print('🔑 Getting license info for key: $licenseKey');
      final rows = await _worksheet!.values.allRows();
      print('🔑 Total rows in worksheet: ${rows.length}');

      final rowIndex =
          rows.indexWhere((row) => row.isNotEmpty && row[0] == licenseKey);
      print('🔑 Found license at row index: $rowIndex');

      if (rowIndex == -1) {
        print('❌ License key not found');
        return null;
      }

      final row = rows[rowIndex];
      print('🔑 License row data: $row');

      // Ensure row has enough elements by padding with nulls if needed
      final paddedRow = List<String?>.from(row);
      while (paddedRow.length < 9) {
        paddedRow.add(null);
      }

      final info = {
        'license': paddedRow[0] ?? '',
        'type': paddedRow[1] ?? '',
        'duration_days': int.tryParse(paddedRow[2] ?? '0') ?? 0,
        'status': paddedRow[3] ?? '',
        'used': int.tryParse(paddedRow[4] ?? '0') ?? 0,
        'activation_date': paddedRow[5],
        'expiration_date': paddedRow[6],
        'machine_id': paddedRow[7] ?? '',
        'notes': paddedRow[8] ?? '',
      };
      print('🔑 Parsed license info: $info');
      return info;
    } catch (e, stackTrace) {
      print('❌ Error getting license info: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> validateLicense(String licenseKey) async {
    try {
      // For normal validation, only check locally
      if (licenseKey.startsWith('QRBARCODE-')) {
        print('🔑 Performing online validation for activation: $licenseKey');

        // Initialize GSheets connection for activation
        if (!_isInitialized) {
          print('🔑 Initializing service for activation');
          await _initializeGSheets();
        }

        final licenseInfo = await _getLicenseInfo(licenseKey);

        if (licenseInfo == null) {
          print('❌ License info not found');
          return false;
        }

        print('🔑 Checking license status');
        if (licenseInfo['status'] != 'valid') {
          print('❌ License status is not valid: ${licenseInfo['status']}');
          return false;
        }

        print('🔑 Checking machine ID');
        final currentMachineId = await getMachineId();

        // If the license is in use, check if it's being used by this machine
        if ((licenseInfo['used'] ?? 0) >= 1) {
          if (licenseInfo['machine_id'] == currentMachineId) {
            print('✅ License is already activated on this machine');
            return true;
          }
          print('❌ License is already in use on another machine');
          return false;
        }

        // For new activations, ensure no machine ID conflict
        if (licenseInfo['machine_id'] != null &&
            licenseInfo['machine_id'].toString().isNotEmpty &&
            licenseInfo['machine_id'] != currentMachineId) {
          print(
              '❌ Machine ID mismatch. Current: $currentMachineId, Registered: ${licenseInfo['machine_id']}');
          return false;
        }

        print('✅ License validation successful');
        return true;
      } else {
        // For normal validation, only check locally
        print('🔑 Performing offline license validation');
        return _checkLocalLicense(licenseKey);
      }
    } catch (e, stackTrace) {
      print('❌ Error validating license: $e');
      print('❌ Stack trace: $stackTrace');
      // For normal validation, fall back to local check
      return _checkLocalLicense(licenseKey);
    }
  }

  Future<bool> activateLicense(String licenseKey) async {
    try {
      print('🔑 Starting license activation for key: $licenseKey');

      // Initialize GSheets connection only during activation
      if (!_isInitialized) {
        await _initializeGSheets();
      }

      if (_worksheet == null) throw Exception('Worksheet not initialized');

      print('🔑 Validating license before activation');
      if (!await validateLicense(licenseKey)) {
        print('❌ License validation failed');
        return false;
      }

      final machineId = await getMachineId();
      final now = DateTime.now();

      print('🔑 Finding license row');
      final rows = await _worksheet!.values.allRows();
      final rowIndex =
          rows.indexWhere((row) => row.isNotEmpty && row[0] == licenseKey);

      if (rowIndex == -1) {
        print('❌ License row not found');
        return false;
      }

      print('🔑 Calculating expiration date');
      final durationDays = int.tryParse(rows[rowIndex][2]) ?? 365;
      final expirationDate = now.add(Duration(days: durationDays));
      print(
          '🔑 License duration: $durationDays days, Expires: ${expirationDate.toIso8601String()}');

      print('🔑 Updating license row');
      final updateData = [
        licenseKey,
        rows[rowIndex][1],
        durationDays.toString(),
        'valid',
        '1',
        now.toIso8601String(),
        expirationDate.toIso8601String(),
        machineId,
        'Activated'
      ];
      print('🔑 Update data: $updateData');

      await _worksheet!.values
          .insertRow(rowIndex + 1, updateData, fromColumn: 1);
      print('✅ License row updated successfully');

      print('🔑 Saving license locally');
      await saveLicenseLocally(licenseKey);

      print('✅ License activation completed successfully');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error activating license: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  bool _checkLocalLicense(String licenseKey) {
    try {
      print('🔑 Checking local license');
      final storedKey = _prefs.getString(_licenseKey);
      print('🔑 Stored license key: $storedKey');
      return storedKey == licenseKey;
    } catch (e, stackTrace) {
      print('❌ Error checking local license: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> saveLicenseLocally(String licenseKey) async {
    try {
      print('🔑 Saving license locally: $licenseKey');
      await _prefs.setString(_licenseKey, licenseKey);
      print('✅ License saved successfully');
    } catch (e, stackTrace) {
      print('❌ Error saving license locally: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<String?> getStoredLicense() async {
    try {
      print('🔑 Getting stored license');
      final license = _prefs.getString(_licenseKey);
      print('🔑 Retrieved stored license: $license');
      return license;
    } catch (e, stackTrace) {
      print('❌ Error getting stored license: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> clearLicense() async {
    try {
      print('🔑 Clearing stored license');
      await _prefs.remove(_licenseKey);
      print('✅ License cleared successfully');
    } catch (e, stackTrace) {
      print('❌ Error clearing license: $e');
      print('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int?> getRemainingDays() async {
    try {
      if (_worksheet == null) throw Exception('Worksheet not initialized');

      print('🔑 Calculating remaining days');
      final machineId = await getMachineId();
      final licenseInfo = await _getLicenseInfo(machineId);

      if (licenseInfo == null) {
        print('❌ No license info found');
        return null;
      }

      final expirationDate = DateTime.parse(licenseInfo['expiration_date']);
      final remaining = expirationDate.difference(DateTime.now()).inDays;
      print('🔑 Remaining days: $remaining');

      return remaining > 0 ? remaining : 0;
    } catch (e, stackTrace) {
      print('❌ Error getting remaining days: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }
}
