import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../constants.dart';  // Import constants for border radius

class UpdateDialog extends StatefulWidget {
  final Map<String, dynamic> updateInfo;
  final UpdateService updateService;
  final VoidCallback? onUpdateComplete;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    required this.updateService,
    this.onUpdateComplete,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isUpdating = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadiusSmallAll,
      ),
      child: ConstrainedBox(
        constraints: kDialogConstraintsMedium,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Version information
              Text('A new version (${widget.updateInfo['latestVersion']}) is available.'),
              const SizedBox(height: 8),
              Text('Current version: ${widget.updateInfo['currentVersion']}'),
              const SizedBox(height: 24),
              
              // Release notes
              if (widget.updateInfo['releaseNotes'] != null) ...[
                const Text(
                  'What\'s new:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: kBorderRadiusSmallAll,
                    ),
                    child: ClipRRect(
                      borderRadius: kBorderRadiusSmallAll,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.updateInfo['releaseNotes']),
                      ),
                    ),
                  ),
                ),
              ],
              
              // Update status
              if (_isUpdating) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  borderRadius: kBorderRadiusSmallAll,
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: TextStyle(
                    color: _status.toLowerCase().contains('error')
                        ? Colors.red
                        : Colors.grey.shade700,
                  ),
                ),
              ],
              
              // Action buttons
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 8),
                  if (!_isUpdating)
                    ElevatedButton(
                      onPressed: _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: kBorderRadiusSmallAll,
                        ),
                      ),
                      child: const Text('Update Now'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdate() async {
    setState(() {
      _isUpdating = true;
      _status = 'Downloading update...';
    });

    try {
      final success = await widget.updateService.downloadAndInstallUpdate(
        widget.updateInfo['downloadUrl'],
        widget.updateInfo['latestVersion'],
      );

      if (success) {
        setState(() => _status = 'Update downloaded. Restarting application...');
        Future.delayed(const Duration(seconds: 2), () {
          widget.onUpdateComplete?.call();
          Navigator.of(context).pop(true);
        });
      } else {
        setState(() {
          _isUpdating = false;
          _status = 'Update failed. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _status = 'Error: ${e.toString()}';
      });
    }
  }
} 