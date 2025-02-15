import 'package:flutter/material.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';
import '../constants.dart';  // Import constants for border radius

// Using a different name since AboutDialog is already a Flutter widget
class AppAboutDialog extends StatelessWidget {
  final String version;
  final String licenseKey;
  final UpdateService updateService;
  final VoidCallback? onVersionChanged;

  const AppAboutDialog({
    super.key,
    required this.version,
    required this.licenseKey,
    required this.updateService,
    this.onVersionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadiusSmallAll,
      ),
      titlePadding: const EdgeInsets.all(24),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actionsPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Image.asset('assets/images/jae-logo.png', height: 40),
          const SizedBox(width: 16),
          const Text('About QRBarcode'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Version: $version'),
          const SizedBox(height: 8),
          Text('License: $licenseKey'),
          const SizedBox(height: 16),
          const Text('JAE QR Barcode System for Production Line'),
          const Text('© 2024 JAE. All rights reserved.'),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.system_update),
              label: const Text('Check for Updates'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: kBorderRadiusSmallAll,
                ),
              ),
              onPressed: () async {
                try {
                  final updateInfo = await updateService.checkForUpdates();
                  if (!context.mounted) return;
                  
                  if (updateInfo['error'] != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error checking for updates: ${updateInfo['error']}'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    return;
                  }
                  
                  if (updateInfo['hasUpdate']) {
                    showDialog(
                      context: context,
                      builder: (context) => UpdateDialog(
                        updateInfo: updateInfo,
                        updateService: updateService,
                        onUpdateComplete: onVersionChanged,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You have the latest version'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to check for updates: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Close'),
        ),
      ],
    );
  }
} 