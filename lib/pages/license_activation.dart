import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../constants.dart';
import '../widgets/about_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/update_service.dart';

class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({Key? key}) : super(key: key);

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  late Future<LicenseService> _licenseServiceFuture;
  final _licenseKeyController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _success;
  String _version = '';
  String _appName = '';
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    _licenseServiceFuture = LicenseService.getInstance();
    _updateService = UpdateService();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final currentVersion = await _updateService.versionService.getCurrentVersion();
      final packageInfo = await PackageInfo.fromPlatform();

      setState(() {
        _version = 'v$currentVersion (${packageInfo.buildNumber})';
        _appName = "JAE QR Barcode System";
      });
    } catch (e) {
      print('Error loading app info: $e');
    }
  }

  Future<void> _activateLicense() async {
    if (_licenseKeyController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a license key';
        _success = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final licenseService = await _licenseServiceFuture;
      final success =
          await licenseService.activateLicense(_licenseKeyController.text);

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (success) {
            _success = 'License activated successfully!';
            _error = null;
            // Navigate to login page after successful activation
            Future.delayed(const Duration(seconds: 1), () {
              Navigator.of(context).pushReplacementNamed('/login');
            });
          } else {
            _error = 'Invalid license key';
            _success = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
          _success = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Card(
              margin: const EdgeInsets.all(32),
              child: Container(
                width: 500,
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QR Barcode System',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'License Activation Required',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    const Text(
                      'License Key',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _licenseKeyController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your license key',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _activateLicense,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Activate License'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Version info and about dialog at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AppAboutDialog(
                        version: _version,
                        licenseKey: 'Not activated',
                        updateService: _updateService,
                        onVersionChanged: _loadAppInfo,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_appName $_version',
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: Color(0xFF666666),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }
}
