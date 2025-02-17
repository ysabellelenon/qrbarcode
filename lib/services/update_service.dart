import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as path;
import 'version_service.dart';

class UpdateService {
  final VersionService _versionService = VersionService();
  
  // Add public getter for version service
  VersionService get versionService => _versionService;
  
  static const String LOG_FILE = 'update_service.log';
  
  // TODO: Replace with your GitHub repository URL
  static const String GITHUB_API_URL = 'https://api.github.com/repos/rickylenon/qrbarcode-releases/releases/latest';
  static const String APP_NAME = 'qrbarcode';

  Future<void> _log(String message) async {
    try {
      final currentExePath = Platform.resolvedExecutable;
      final appDir = path.dirname(currentExePath);
      final logFile = File(path.join(appDir, LOG_FILE));
      final timestamp = DateTime.now().toString();
      await logFile.writeAsString('[$timestamp] $message\n', mode: FileMode.append);
      print('[$timestamp] $message'); // Also print to console
    } catch (e) {
      print('Error writing to log: $e');
    }
  }

  Future<Map<String, dynamic>> checkForUpdates() async {
    try {
      await _log('Checking for updates...');
      final currentVersion = await _versionService.getCurrentVersion();
      await _log('Current version: $currentVersion');

      await _log('Fetching latest release from GitHub...');
      final response = await http.get(Uri.parse(GITHUB_API_URL));
      await _log('GitHub API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final releaseData = json.decode(response.body);
        final latestVersion = releaseData['tag_name'].toString().replaceAll('v', '');
        await _log('Latest version from GitHub: $latestVersion');

        final hasUpdate = _isNewerVersion(currentVersion, latestVersion);
        await _log('Update available: $hasUpdate');

        return {
          'hasUpdate': hasUpdate,
          'currentVersion': currentVersion,
          'latestVersion': latestVersion,
          'releaseNotes': releaseData['body'],
          'downloadUrl': _getCorrectAssetUrl(releaseData['assets']),
        };
      }
      await _log('Failed to check for updates: ${response.statusCode}');
      return {'hasUpdate': false, 'error': 'Failed to check for updates'};
    } catch (e) {
      await _log('Error checking for updates: $e');
      return {'hasUpdate': false, 'error': e.toString()};
    }
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      List<int> current = currentVersion.split('.').map(int.parse).toList();
      List<int> latest = latestVersion.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      _log('Error comparing versions: $e');
      return false;
    }
  }

  String _getCorrectAssetUrl(List<dynamic> assets) {
    // Check if running on ARM
    bool isArm = Platform.version.toLowerCase().contains('arm');
    
    for (var asset in assets) {
      String name = asset['name'].toString().toLowerCase();
      if (isArm && name.contains('arm64')) {
        return asset['browser_download_url'];
      } else if (!isArm && name.contains('x64')) {
        return asset['browser_download_url'];
      }
    }
    
    // Default to first asset if no specific match found
    return assets.first['browser_download_url'];
  }

  Future<bool> downloadAndInstallUpdate(String downloadUrl, String newVersion) async {
    try {
      await _log('Starting update download...');
      final tempDir = await getTemporaryDirectory();
      final downloadPath = path.join(tempDir.path, 'update.zip');
      
      await _log('Downloading from: $downloadUrl');
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        await _log('Download completed successfully');
        await File(downloadPath).writeAsBytes(response.bodyBytes);
        
        // Update version before creating update script
        await _log('Updating version to: $newVersion');
        await _versionService.updateVersion(newVersion);
        
        // Verify version was updated
        final currentVersion = await _versionService.getCurrentVersion();
        await _log('Verified current version after update: $currentVersion');
        
        if (currentVersion != newVersion) {
          await _log('Error: Version not updated correctly');
          return false;
        }
        
        await _log('Creating update script...');
        await _createUpdateScript(downloadPath);
        
        await _log('Executing update script...');
        await Process.run('cmd', ['/c', 'start', '', path.join(tempDir.path, 'update.bat')]);
        return true;
      }
      await _log('Download failed: ${response.statusCode}');
      return false;
    } catch (e) {
      await _log('Update error: $e');
      return false;
    }
  }

  Future<void> _createUpdateScript(String updateZipPath) async {
    final tempDir = await getTemporaryDirectory();
    final scriptPath = path.join(tempDir.path, 'update.bat');
    final currentExePath = Platform.resolvedExecutable;
    final appDir = path.dirname(currentExePath);

    await _log('Creating update script at: $scriptPath');
    await _log('Current exe path: $currentExePath');
    await _log('App directory: $appDir');

    final script = '''
@echo off
echo Updating ${APP_NAME}...
timeout /t 2 /nobreak > nul

:: Kill running instance
taskkill /F /IM ${APP_NAME}.exe /T
timeout /t 2 /nobreak > nul

:: Extract update
powershell -Command "Expand-Archive -Path '$updateZipPath' -DestinationPath '$appDir' -Force"

:: Cleanup
del "$updateZipPath"

:: Restart app
start "" "$currentExePath"
del "%~f0"
''';

    await File(scriptPath).writeAsString(script);
    await _log('Update script created successfully');
  }
} 