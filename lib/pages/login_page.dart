import 'package:flutter/material.dart';
import '../constants.dart'; // Import the constants file
import '../database_helper.dart';
import '../services/license_service.dart';
import '../services/update_service.dart';
import '../widgets/about_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _licenseKey;
  String _version = '';
  String _appName = '';
  late final UpdateService _updateService;

  @override
  void initState() {
    super.initState();
    _updateService = UpdateService();
    _checkLicense();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final currentVersion = await _updateService.versionService.getCurrentVersion();
      final licenseService = await LicenseService.getInstance();
      final storedLicense = await licenseService.getStoredLicense();
      final packageInfo = await PackageInfo.fromPlatform();

      setState(() {
        _version = packageInfo.buildNumber.isNotEmpty 
            ? 'v$currentVersion (${packageInfo.buildNumber})'
            : 'v$currentVersion';
        _appName = "JAE QR Barcode System";
        _licenseKey = storedLicense ?? "Not activated";
      });
    } catch (e) {
      print('Error loading app info: $e');
    }
  }

  Future<void> _checkLicense() async {
    try {
      final licenseService = await LicenseService.getInstance();
      final storedLicense = await licenseService.getStoredLicense();

      if (storedLicense == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/activate');
        }
      }
    } catch (e) {
      print('Error checking license: $e');
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/activate');
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final username = _usernameController.text;
        final password = _passwordController.text;

        if (username.isEmpty || password.isEmpty) {
          throw Exception('Username and password cannot be empty');
        }

        print('DEBUG: Attempting login with username: $username');
        final user = await DatabaseHelper().getUserByUsernameAndPassword(
          username,
          password,
        );
        print('DEBUG: Login result username: ${user?['username']}');

        if (user != null) {
          // Store the current user ID
          print('DEBUG: Setting current user ID: ${user['id']}');
          await DatabaseHelper().setCurrentUserId(user['id'] as int);

          // Verify the current user was set
          final currentUser = await DatabaseHelper().getCurrentUser();
          print('DEBUG: Verified current user username after setting: ${currentUser?['username']}');

          if (mounted) {
            setState(() {
              _isLoading = false;
            });

            // Check the category/line number
            if (user['lineNo'] == 'Assembly') {
              Navigator.pushReplacementNamed(context, '/operator-login');
            } else {
              Navigator.pushReplacementNamed(context, '/engineer-login');
            }
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false; // Set loading to false when login fails
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid username or password'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Stack(
        children: [
          Center(
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: kBorderRadiusSmallAll,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/jae-logo.png',
                        height: 100,
                      ),
                      const SizedBox(height: 32),

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Employee ID',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                            borderRadius: kBorderRadiusSmallAll,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        onFieldSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: kBorderRadiusSmallAll,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: kBorderRadiusSmallAll,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // License information footer at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(  // Add Material widget to ensure InkWell works
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        print('About dialog tapped'); // Add debug print
                        showDialog(
                          context: context,
                          builder: (context) => AppAboutDialog(
                            version: _version,
                            licenseKey: _licenseKey ?? 'Not activated',
                            updateService: _updateService,
                            onVersionChanged: _loadAppInfo,
                          ),
                        );
                      },
                      child: Padding( // Add padding for better touch target
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
                    const SizedBox(height: 4),
                    if (_licenseKey != null)
                      Text(
                        'License: $_licenseKey',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
