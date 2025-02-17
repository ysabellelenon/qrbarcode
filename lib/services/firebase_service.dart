import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../firebase_options.dart';
import 'dart:async';
import 'dart:io';

class FirebaseService {
  static FirebaseService? _instance;
  late FirebaseFirestore _firestore;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _isInitialized = false;

  // Collection names
  static const String _licensesCollection = 'licenses';
  static const String _activationsCollection = 'activations';

  FirebaseService._();

  static Future<FirebaseService> getInstance() async {
    if (_instance == null) {
      _instance = FirebaseService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 Initializing Firebase Service...');

      // Check if Firebase is already initialized
      if (Firebase.apps.isEmpty) {
        print('🔄 Initializing Firebase Core...');
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        print('✅ Firebase Core initialized');
      } else {
        print('ℹ️ Firebase Core already initialized');
      }

      // Configure Firestore settings for Windows and macOS
      final settings = Platform.isWindows || Platform.isMacOS
          ? const Settings(
              persistenceEnabled: false,
              cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
            )
          : const Settings();

      _firestore = FirebaseFirestore.instance;
      _firestore.settings = settings;

      print(
          '✅ Firestore configured with persistence ${Platform.isWindows || Platform.isMacOS ? 'disabled' : 'enabled'}');
      _isInitialized = true;
      print('✅ Firebase Service initialized');
    } catch (e, stackTrace) {
      print('❌ Error initializing Firebase Service: $e');
      print('Stack trace: $stackTrace');
      _isInitialized = false;
      rethrow;
    }
  }

  // Get unique hardware ID
  Future<String> getHardwareId() async {
    try {
      print('🔄 Getting hardware ID...');
      String rawId;

      if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        rawId = '${windowsInfo.computerName}'
            '${windowsInfo.numberOfCores}'
            '${windowsInfo.systemMemoryInMegabytes}'
            '${windowsInfo.userName}';
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfo.macOsInfo;
        rawId = '${macOsInfo.computerName}'
            '${macOsInfo.arch}'
            '${macOsInfo.model}'
            '${macOsInfo.systemGUID ?? ''}'
            '${macOsInfo.kernelVersion}';
      } else {
        throw UnsupportedError(
            'Platform ${Platform.operatingSystem} is not supported');
      }

      // Create a SHA-256 hash of the hardware info
      final bytes = utf8.encode(rawId);
      final digest = sha256.convert(bytes);

      final hardwareId = digest.toString();
      print('✅ Hardware ID generated: ${hardwareId.substring(0, 8)}...');
      return hardwareId;
    } catch (e) {
      print('❌ Error getting hardware ID: $e');
      rethrow;
    }
  }

  // Test write to Firebase
  Future<void> testWrite() async {
    if (!_isInitialized) {
      print('⚠️ Firebase Service not initialized. Initializing...');
      await _initialize();
    }

    try {
      print('🔄 Starting test write...');
      final hardwareId = await getHardwareId();

      final docRef = await _firestore.collection('test').add({
        'hardware_id': hardwareId,
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Test write from Windows app',
        'app_version': '0.1.1',
      });

      print('✅ Test write successful. Document ID: ${docRef.id}');
    } catch (e) {
      print('❌ Error writing to Firebase: $e');
      rethrow;
    }
  }

  // Test read from Firebase
  Future<List<Map<String, dynamic>>> testRead() async {
    if (!_isInitialized) {
      print('⚠️ Firebase Service not initialized. Initializing...');
      await _initialize();
    }

    try {
      print('🔄 Starting test read...');
      final querySnapshot = await _firestore.collection('test').get();
      final results = querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      print('✅ Test read successful: ${results.length} documents');
      return results;
    } catch (e) {
      print('❌ Error reading from Firebase: $e');
      rethrow;
    }
  }

  // Check if license exists and is valid
  Future<Map<String, dynamic>?> validateLicenseOnline(String licenseKey) async {
    if (!_isInitialized) {
      try {
        await _initialize();
      } catch (e) {
        print('❌ Error initializing Firebase during validation: $e');
        return null;
      }
    }

    try {
      print('🔄 Validating license: $licenseKey');

      // Get the license document from Firestore
      final docSnapshot = await _firestore
          .collection(_licensesCollection)
          .doc(licenseKey)
          .get();

      // Only check if document exists and hardware_id is null
      if (!docSnapshot.exists) {
        print('❌ License not found');
        return null;
      }

      final data = docSnapshot.data()!;
      if (data['hardware_id'] != null) {
        print('❌ License already in use');
        return null;
      }

      print('✅ License is valid and available');
      return data;
    } catch (e) {
      print('❌ Error validating license: $e');
      return null;
    }
  }

  // Activate license and store hardware ID
  Future<bool> activateLicense(String licenseKey) async {
    if (!_isInitialized) {
      try {
        await _initialize();
      } catch (e) {
        print('❌ Error initializing Firebase during activation: $e');
        return false;
      }
    }

    String? hardwareId;
    try {
      print('🔄 Starting activation for license: $licenseKey');

      // Step 1: Get hardware ID
      try {
        hardwareId = await getHardwareId();
        print('✅ Hardware ID for activation: ${hardwareId.substring(0, 8)}...');
      } catch (e) {
        print('❌ Error getting hardware ID: $e');
        return false;
      }

      // Step 2: Get document reference
      print('📄 Getting document reference...');
      final docRef = _firestore.collection(_licensesCollection).doc(licenseKey);

      // Step 3: Get document snapshot outside transaction
      print('📄 Checking document...');
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        print('❌ License document not found');
        return false;
      }

      final data = docSnapshot.data()!;
      if (data['hardware_id'] != null) {
        print('❌ License already has hardware_id: ${data['hardware_id']}');
        return false;
      }

      // Step 4: Perform update without transaction
      print('📝 Updating document...');
      await docRef.update({
        'hardware_id': hardwareId,
        'activation_date': FieldValue.serverTimestamp(),
      });

      print('✅ License activation successful');
      return true;
    } catch (e, stackTrace) {
      print('❌ Error during license activation:');
      print('Error: $e');
      print('Stack trace: $stackTrace');

      // Try to rollback if possible
      if (hardwareId != null) {
        try {
          print('🔄 Attempting to rollback changes...');
          final docRef =
              _firestore.collection(_licensesCollection).doc(licenseKey);
          await docRef.update({'hardware_id': null, 'activation_date': null});
          print('✅ Rollback successful');
        } catch (rollbackError) {
          print('⚠️ Rollback failed: $rollbackError');
        }
      }

      return false;
    }
  }

  // Check if hardware ID is already registered
  Future<bool> isHardwareIdRegistered(String hardwareId) async {
    // Always return false since we're not checking hardware IDs anymore
    return false;
  }

  // Debug function to list all licenses
  Future<void> debugListAllLicenses() async {
    if (!_isInitialized) {
      try {
        await _initialize();
      } catch (e) {
        print('❌ Error initializing Firebase during debug: $e');
        return;
      }
    }

    try {
      print('\n📄 DEBUG: Listing all licenses in Firestore');
      print('----------------------------------------');

      final querySnapshot =
          await _firestore.collection(_licensesCollection).get();

      if (querySnapshot.docs.isEmpty) {
        print('No licenses found in collection: $_licensesCollection');
        return;
      }

      for (var doc in querySnapshot.docs) {
        print('License Key: ${doc.id}');
        print('Data: ${doc.data()}');
        print('----------------------------------------');
      }
    } catch (e) {
      print('❌ Error listing licenses: $e');
    }
  }
}
