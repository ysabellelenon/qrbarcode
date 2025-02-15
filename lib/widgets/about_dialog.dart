import 'package:flutter/material.dart';
import '../services/update_service.dart';
import 'update_dialog.dart';
import '../constants.dart';  // Import constants for border radius

// Using a different name since AboutDialog is already a Flutter widget
class AppAboutDialog extends StatefulWidget {
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
  State<AppAboutDialog> createState() => _AppAboutDialogState();
}

class _AppAboutDialogState extends State<AppAboutDialog> {
  String? _statusMessage;
  bool _isChecking = false;

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
          Text('Version: ${widget.version}'),
          const SizedBox(height: 8),
          Text('License: ${widget.licenseKey}'),
          const SizedBox(height: 16),
          const Text('JAE QR Barcode System for Production Line'),
          const Text('© 2024 JAE. All rights reserved.'),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  icon: _isChecking 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.system_update),
                  label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: kBorderRadiusSmallAll,
                    ),
                  ),
                  onPressed: _isChecking ? null : () async {
                    setState(() {
                      _isChecking = true;
                      _statusMessage = null;
                    });
                    
                    try {
                      final updateInfo = await widget.updateService.checkForUpdates();
                      if (!mounted) return;
                      
                      setState(() {
                        _isChecking = false;
                      });
                      
                      if (updateInfo['error'] != null) {
                        setState(() {
                          _statusMessage = 'Error: ${updateInfo['error']}';
                        });
                        return;
                      }
                      
                      if (updateInfo['hasUpdate']) {
                        showDialog(
                          context: context,
                          builder: (context) => UpdateDialog(
                            updateInfo: updateInfo,
                            updateService: widget.updateService,
                            onUpdateComplete: widget.onVersionChanged,
                          ),
                        );
                      } else {
                        setState(() {
                          _statusMessage = 'You have the latest version (${widget.version})';
                        });
                      }
                    } catch (e) {
                      if (!mounted) return;
                      setState(() {
                        _isChecking = false;
                        _statusMessage = 'Failed to check for updates: ${e.toString()}';
                      });
                    }
                  },
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage!.startsWith('Error') || _statusMessage!.startsWith('Failed')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ],
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