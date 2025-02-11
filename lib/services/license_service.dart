import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;

class LicenseService {
  static const String _credentialsPath = 'assets/credentials.json';
  static const String _sheetId =
      'YOUR_SHEET_ID'; // Replace with your Google Sheet ID
  static const String _licenseKey = 'license_key';
  static const String _deviceId = 'device_id';

  static LicenseService? _instance;
  late SharedPreferences _prefs;
  late SheetsApi _sheetsApi;
  bool _isInitialized = false;

  LicenseService._();

  static Future<LicenseService> getInstance() async {
    if (_instance == null) {
      _instance = LicenseService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Load Google Sheets credentials
      final credentialsJson = await rootBundle.loadString(_credentialsPath);
      final credentials = auth.ServiceAccountCredentials.fromJson(
        json.decode(credentialsJson),
      );

      final client = await auth.clientViaServiceAccount(
        credentials,
        [SheetsApi.spreadsheetsReadonlyScope],
      );

      _sheetsApi = SheetsApi(client);
      _isInitialized = true;
    } catch (e) {
      print('Failed to initialize LicenseService: $e');
      rethrow;
    }
  }

  Future<String> _getDeviceId() async {
    String? storedDeviceId = _prefs.getString(_deviceId);
    if (storedDeviceId != null) return storedDeviceId;

    final deviceInfo = DeviceInfoPlugin();
    final windowsInfo = await deviceInfo.windowsInfo;

    // Create a unique device identifier
    final deviceId = base64Encode(
        utf8.encode('${windowsInfo.computerName}-${windowsInfo.deviceId}'));

    await _prefs.setString(_deviceId, deviceId);
    return deviceId;
  }

  Future<bool> validateLicense(String licenseKey) async {
    try {
      if (!_isInitialized) await _initialize();

      final deviceId = await _getDeviceId();

      // Read license data from Google Sheet
      final response = await _sheetsApi.spreadsheets.values.get(
        _sheetId,
        'Licenses!A:C', // Assumes columns: License Key | Device ID | Status
      );

      final values = response.values;
      if (values == null || values.isEmpty) return false;

      // Find matching license key
      for (var row in values.skip(1)) {
        // Skip header row
        if (row.length >= 3 &&
            row[0] == licenseKey &&
            row[2].toString().toLowerCase() == 'active') {
          if (row[1] == '') {
            // First time activation - register device
            await _registerDevice(licenseKey, deviceId);
            return true;
          } else if (row[1] == deviceId) {
            // Device already registered with this license
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      print('License validation failed: $e');
      // If validation fails (e.g., no internet), check local storage
      return _checkLocalLicense(licenseKey);
    }
  }

  Future<void> _registerDevice(String licenseKey, String deviceId) async {
    try {
      // Find the row with matching license key
      final response = await _sheetsApi.spreadsheets.values.get(
        _sheetId,
        'Licenses!A:A',
      );

      final values = response.values;
      if (values == null) return;

      int rowIndex = 0;
      for (var i = 0; i < values.length; i++) {
        if (values[i][0] == licenseKey) {
          rowIndex = i + 1; // 1-based index for Sheets API
          break;
        }
      }

      if (rowIndex > 0) {
        // Update device ID in the sheet
        await _sheetsApi.spreadsheets.values.update(
          ValueRange(values: [
            [deviceId]
          ]),
          _sheetId,
          'Licenses!B$rowIndex',
          valueInputOption: 'RAW',
        );
      }
    } catch (e) {
      print('Failed to register device: $e');
    }
  }

  bool _checkLocalLicense(String licenseKey) {
    final storedKey = _prefs.getString(_licenseKey);
    return storedKey == licenseKey;
  }

  Future<void> saveLicenseLocally(String licenseKey) async {
    await _prefs.setString(_licenseKey, licenseKey);
  }

  Future<String?> getStoredLicense() async {
    return _prefs.getString(_licenseKey);
  }

  Future<void> clearLicense() async {
    await _prefs.remove(_licenseKey);
  }
}
