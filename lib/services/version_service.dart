import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static const String VERSION_FILE = 'version.txt';
  
  Future<String> getCurrentVersion() async {
    try {
      // First try to read from version file
      final version = await _readVersionFile();
      if (version != null) {
        return version;
      }
      
      // If file doesn't exist, fall back to package info
      final packageInfo = await PackageInfo.fromPlatform();
      final initialVersion = packageInfo.version;
      
      // Create version file with initial version
      await _writeVersionFile(initialVersion);
      print('Created version file with version: $initialVersion');
      return initialVersion;
    } catch (e) {
      print('Error getting version: $e');
      // Fall back to package info if anything goes wrong
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    }
  }

  Future<void> updateVersion(String newVersion) async {
    await _writeVersionFile(newVersion);
  }

  Future<String?> _readVersionFile() async {
    try {
      final file = await _getVersionFile();
      if (await file.exists()) {
        final version = await file.readAsString();
        return version.trim();
      }
      return null;
    } catch (e) {
      print('Error reading version file: $e');
      return null;
    }
  }

  Future<void> _writeVersionFile(String version) async {
    try {
      final file = await _getVersionFile();
      await file.writeAsString(version.trim());
    } catch (e) {
      print('Error writing version file: $e');
    }
  }

  Future<File> _getVersionFile() async {
    final currentExePath = Platform.resolvedExecutable;
    final appDir = path.dirname(currentExePath);
    return File(path.join(appDir, VERSION_FILE));
  }

  // Only reset if no version file exists
  Future<void> reset() async {
    try {
      final file = await _getVersionFile();
      if (!await file.exists()) {
        print('No version file found, will create on first getCurrentVersion() call');
      } else {
        final version = await file.readAsString();
        print('Existing version file found with version: ${version.trim()}');
      }
    } catch (e) {
      print('Error checking version file: $e');
    }
  }
} 