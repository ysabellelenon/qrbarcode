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
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadiusSmallAll,
      ),
      title: Text('Update Available'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A new version (${widget.updateInfo['latestVersion']}) is available.'),
          const SizedBox(height: 8),
          Text('Current version: ${widget.updateInfo['currentVersion']}'),
          const SizedBox(height: 16),
          if (widget.updateInfo['releaseNotes'] != null) ...[
            Text('What\'s new:'),
            Container(
              height: 100,
              width: 300,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                child: Text(widget.updateInfo['releaseNotes']),
              ),
            ),
          ],
          if (_isUpdating) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(_status),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Later'),
        ),
        if (!_isUpdating)
          ElevatedButton(
            onPressed: _handleUpdate,
            child: Text('Update Now'),
          ),
      ],
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