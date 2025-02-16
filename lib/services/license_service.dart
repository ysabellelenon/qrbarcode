import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database_helper.dart';
import 'package:sqflite/sqflite.dart';
import 'firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseService {
  static LicenseService? _instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  FirebaseService? _firebaseService;
  bool _isFirebaseInitialized = false;

  LicenseService._();

  static Future<LicenseService> getInstance() async {
    print('🔑 Getting LicenseService instance');
    if (_instance == null) {
      _instance = LicenseService._();
    }
    return _instance!;
  }

  Future<void> _initializeFirebase() async {
    if (_isFirebaseInitialized) return;

    try {
      print('🔥 Initializing Firebase for license validation...');
      
      // Initialize Firebase Core
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Clear persistence to prevent Windows crashes
      try {
        print('🧹 Clearing Firestore cache...');
        await FirebaseFirestore.instance.clearPersistence();
        print('✅ Firestore cache cleared successfully');
      } catch (e) {
        print('⚠️ Failed to clear Firestore cache: $e');
        // Continue even if clearing cache fails
      }

      // Initialize Firebase Service
      _firebaseService = await FirebaseService.getInstance();
      _isFirebaseInitialized = true;
      print('✅ Firebase initialized for license validation');

      // Debug: List all licenses
      await _firebaseService?.debugListAllLicenses();
    } catch (e) {
      print('❌ Error initializing Firebase: $e');
      _isFirebaseInitialized = false;
      throw e;
    }
  }

  Future<bool> validateLicense(String licenseKey) async {
    try {
      print('🔑 Validating license: $licenseKey');
      
      if (licenseKey.isEmpty) {
        print('❌ License key is empty');
        return false;
      }

      // First check if it's already activated locally
      try {
        if (await _checkLocalLicense(licenseKey)) {
          print('✅ License already activated locally');
          return true;
        }
      } catch (e) {
        print('⚠️ Error checking local license: $e');
        // If we can't check locally, we'll need to validate online
      }

      // Initialize Firebase only if we need online validation
      try {
        await _initializeFirebase();
      } catch (e) {
        print('❌ Failed to initialize Firebase for validation: $e');
        return false;
      }

      // Validate against Firestore
      final licenseData = await _firebaseService?.validateLicenseOnline(licenseKey);
      if (licenseData == null) {
        print('❌ License is invalid or already activated');
        return false;
      }

      print('✅ License is valid and available for activation');
      return true;
    } catch (e) {
      print('❌ Error validating license: $e');
      return false;
    }
  }

  Future<bool> activateLicense(String licenseKey) async {
    try {
      print('🔑 Starting license activation for key: $licenseKey');
      
      if (licenseKey.isEmpty) {
        print('❌ Cannot activate empty license key');
        return false;
      }

      // Check if already activated locally
      try {
        if (await _checkLocalLicense(licenseKey)) {
          print('ℹ️ License already activated locally');
          return true;
        }
      } catch (e) {
        print('⚠️ Error checking local license: $e');
        // Continue with activation even if local check fails
      }

      // Initialize Firebase for online activation
      try {
        await _initializeFirebase();
      } catch (e) {
        print('❌ Failed to initialize Firebase for activation: $e');
        return false;
      }

      // Validate and activate in Firestore
      final licenseData = await _firebaseService?.validateLicenseOnline(licenseKey);
      if (licenseData == null) {
        print('❌ License is invalid or already activated');
        return false;
      }

      // Activate in Firestore
      final activated = await _firebaseService?.activateLicense(licenseKey);
      if (activated != true) {
        print('❌ Failed to activate license in Firestore');
        return false;
      }

      // If we got here, the license is activated in Firestore
      // Try to save locally, but don't fail if it doesn't work
      try {
        await saveLicenseLocally(licenseKey);
        print('✅ License saved locally');
      } catch (e) {
        // If we fail to save locally, log it but still return true
        // because the license is valid in Firestore
        print('⚠️ Warning: License activated in Firestore but failed to save locally: $e');
        print('ℹ️ The app will try to save the license again on next startup');
      }

      print('✅ License activation completed successfully');
      return true;
    } catch (e) {
      print('❌ Error during license activation process: $e');
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
    } catch (e) {
      print('❌ Error checking local license: $e');
      // If we can't check the local license, assume it's not activated
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
          'hardware_id': '', // Empty hardware_id since we're not using it
          'activated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('✅ License saved successfully');
    } catch (e) {
      print('❌ Error saving license: $e');
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
    } catch (e) {
      print('❌ Error getting stored license: $e');
      return null;
    }
  }

  Future<void> clearLicense() async {
    try {
      print('🔑 Clearing stored license');
      final db = await _dbHelper.database;
      await db.delete('license_info');
      print('✅ License cleared successfully');
    } catch (e) {
      print('❌ Error clearing license: $e');
      rethrow;
    }
  }
}
