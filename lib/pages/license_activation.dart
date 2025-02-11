import 'package:flutter/material.dart';
import '../services/license_service.dart';

class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({Key? key}) : super(key: key);

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  late Future<LicenseService> _licenseServiceFuture;
  final _licenseKeyController = TextEditingController();
  String? _machineId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _licenseServiceFuture = LicenseService.getInstance();
    _loadMachineId();
  }

  Future<void> _loadMachineId() async {
    try {
      final licenseService = await _licenseServiceFuture;
      final machineId = await licenseService.getMachineId();
      if (mounted) {
        setState(() {
          _machineId = machineId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _activateLicense() async {
    if (_licenseKeyController.text.isEmpty) {
      setState(() {
        _error = 'Please enter a license key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final licenseService = await _licenseServiceFuture;
      final licenseKey = _licenseKeyController.text.trim();

      // Try to activate the license
      final isActivated = await licenseService.activateLicense(licenseKey);
      if (!isActivated) {
        throw Exception(
            'License activation failed. Please check your license key and try again.');
      }

      if (!mounted) return;

      // Navigate to login page after successful activation
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
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
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                      const Text(
                        'Machine ID',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _machineId ?? 'Error getting machine ID',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 32),
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
                          onPressed: _activateLicense,
                          child: const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Activate License'),
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
