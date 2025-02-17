import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'dart:async';

class LogService {
  static LogService? _instance;
  late final File _logFile;
  IOSink? _logSink;
  static const String LOG_FILENAME = 'qrbarcode.log';
  
  // Log rotation settings
  static const int MAX_LOG_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
  // static const int MAX_LOG_SIZE_BYTES = 512; // 512 bytes for testing
  static const int MAX_BACKUP_FILES = 5;
  static const String BACKUP_EXTENSION = '.bak';

  LogService._();

  static Future<LogService> getInstance() async {
    if (_instance == null) {
      _instance = LogService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    try {
      // Get the executable path for the app
      final currentExePath = Platform.resolvedExecutable;
      final appDir = path.dirname(currentExePath);
      _logFile = File(path.join(appDir, LOG_FILENAME));

      // Create log file if it doesn't exist
      if (!await _logFile.exists()) {
        await _logFile.create();
      }
      
      // Open the file for writing
      _logSink = _logFile.openWrite(mode: FileMode.append);
      
      await log('Log file initialized');

      // Check if rotation is needed on startup
      await _checkRotation();
    } catch (e) {
      debugPrint('Error initializing LogService: $e');
    }
  }

  Future<void> _checkRotation() async {
    try {
      if (!await _logFile.exists()) return;

      final fileStats = await _logFile.stat();
      if (fileStats.size >= MAX_LOG_SIZE_BYTES) {
        await _rotateLogFiles();
      }
    } catch (e) {
      debugPrint('Error checking log rotation: $e');
    }
  }

  Future<void> _rotateLogFiles() async {
    try {
      // Close current log file
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;

      final directory = _logFile.parent;
      final baseFileName = path.basenameWithoutExtension(_logFile.path);
      final extension = path.extension(_logFile.path);

      // Build list of backup files from newest to oldest
      final backupFiles = <File>[];
      for (var i = 1; i <= MAX_BACKUP_FILES; i++) {
        final backupFile = File(path.join(
          directory.path,
          '$baseFileName$extension${BACKUP_EXTENSION}$i',
        ));
        if (await backupFile.exists()) {
          backupFiles.add(backupFile);
        }
      }

      // Shift existing backups (from oldest to newest)
      for (var i = backupFiles.length - 1; i >= 0; i--) {
        final currentFile = backupFiles[i];
        final newNumber = i + 2; // +2 because we're making room for .bak1
        if (newNumber <= MAX_BACKUP_FILES) {
          final newFile = File(path.join(
            directory.path,
            '$baseFileName$extension${BACKUP_EXTENSION}$newNumber',
          ));
          await currentFile.rename(newFile.path);
        } else {
          // Delete files that would exceed our max backup count
          await currentFile.delete();
        }
      }

      // Copy current log file to .bak1 (instead of renaming)
      if (await _logFile.exists()) {
        final firstBackup = File(path.join(
          directory.path,
          '$baseFileName$extension${BACKUP_EXTENSION}1',
        ));
        await _logFile.copy(firstBackup.path);
        await _logFile.writeAsString(''); // Clear current log file
      }

      // Reopen the log file for writing
      _logSink = _logFile.openWrite(mode: FileMode.append);
      await log('Log file rotated');
    } catch (e) {
      debugPrint('Error rotating log files: $e');
      // Ensure the sink is reopened even if rotation fails
      if (_logSink == null) {
        _logSink = _logFile.openWrite(mode: FileMode.append);
      }
    }
  }

  Future<T> runWithLogs<T>(Future<T> Function() body) async {
    return await runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
          parent.print(zone, line);
          _logPrint(line);
        },
      ),
    );
  }

  void _logPrint(String message) {
    log(message, level: 'PRINT');
  }

  Future<void> log(String message, {String level = 'INFO'}) async {
    try {
      final timestamp = DateTime.now().toString();
      final logMessage = '[$timestamp] [$level] $message\n';
      
      // Check rotation before writing
      await _checkRotation();
      
      // Write to file
      _logSink?.write(logMessage);
      await _logSink?.flush();
      
      // Also print to console in debug mode if it's not a PRINT level message
      if (kDebugMode && level != 'PRINT') {
        debugPrint(logMessage.trim());
      }
    } catch (e) {
      // Only log errors that aren't related to StreamSink binding
      if (!e.toString().contains('StreamSink is bound to a stream')) {
        debugPrint('Error writing to log file: $e');
      }
    }
  }

  Future<void> error(String message) async {
    await log(message, level: 'ERROR');
  }

  Future<void> warning(String message) async {
    await log(message, level: 'WARNING');
  }

  Future<void> debug(String message) async {
    if (kDebugMode) {
      await log(message, level: 'DEBUG');
    }
  }

  Future<String> getLogFilePath() async {
    return _logFile.path;
  }

  Future<List<String>> getLogFilePaths() async {
    final List<String> paths = [];
    final directory = _logFile.parent;
    final baseFileName = path.basenameWithoutExtension(_logFile.path);
    final extension = path.extension(_logFile.path);

    // Add current log file
    paths.add(_logFile.path);

    // Add backup files
    for (var i = 1; i <= MAX_BACKUP_FILES; i++) {
      final backupFile = File(path.join(
        directory.path,
        '$baseFileName$extension${BACKUP_EXTENSION}$i',
      ));
      if (await backupFile.exists()) {
        paths.add(backupFile.path);
      }
    }

    return paths;
  }

  Future<void> clearLogs() async {
    try {
      // Close current log sink
      await _logSink?.flush();
      await _logSink?.close();
      _logSink = null;

      // Clear current log file
      await _logFile.writeAsString('');
      
      // Delete all backup files
      final directory = _logFile.parent;
      final baseFileName = path.basenameWithoutExtension(_logFile.path);
      final extension = path.extension(_logFile.path);

      for (var i = 1; i <= MAX_BACKUP_FILES; i++) {
        final backupFile = File(path.join(
          directory.path,
          '$baseFileName$extension${BACKUP_EXTENSION}$i',
        ));
        if (await backupFile.exists()) {
          await backupFile.delete();
        }
      }

      // Reopen log sink
      _logSink = _logFile.openWrite(mode: FileMode.append);
      await log('Log files cleared');
    } catch (e) {
      debugPrint('Error clearing log files: $e');
      // Ensure the sink is reopened even if clearing fails
      if (_logSink == null) {
        _logSink = _logFile.openWrite(mode: FileMode.append);
      }
    }
  }
} 