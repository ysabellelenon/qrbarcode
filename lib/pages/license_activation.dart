import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../constants.dart';

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

  @override
  void initState() {
    super.initState();
    _licenseServiceFuture = LicenseService.getInstance();
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
      body: Center(
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
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }
}
