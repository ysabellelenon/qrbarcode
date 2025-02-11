import 'package:flutter/material.dart';
import '../services/license_service.dart';

class LicenseActivationPage extends StatefulWidget {
  const LicenseActivationPage({Key? key}) : super(key: key);

  @override
  State<LicenseActivationPage> createState() => _LicenseActivationPageState();
}

class _LicenseActivationPageState extends State<LicenseActivationPage> {
  final _formKey = GlobalKey<FormState>();
  final _licenseController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _activateLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final licenseService = await LicenseService.getInstance();
      final isValid =
          await licenseService.validateLicense(_licenseController.text);

      if (isValid) {
        await licenseService.saveLicenseLocally(_licenseController.text);
        if (mounted) {
          Navigator.of(context)
              .pushReplacementNamed('/'); // Navigate to main app
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid license key or license is already in use';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to validate license. Please check your internet connection.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'QR Barcode System',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Key',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your license key';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _activateLicense,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Activate License'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
