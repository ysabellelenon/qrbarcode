import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import sqflite_common_ffi
import 'package:flutter/foundation.dart';
import 'package:window_size/window_size.dart';
import 'utils/db_path_printer.dart';
import 'pages/login_page.dart';
import 'pages/engineer_login.dart';
import 'pages/account_settings.dart';
import 'pages/manage_accounts.dart';
import 'pages/new_account.dart';
import 'pages/edit_user.dart';
import 'pages/item_masterlist.dart';
import 'pages/register_item.dart';
import 'pages/revise_item.dart';
import 'pages/operator_login.dart';
import 'pages/license_activation.dart';
import 'database_helper.dart';
import 'services/license_service.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set window size for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    setWindowTitle('QR Barcode System');
    getCurrentScreen().then((screen) {
      if (screen != null) {
        final screenFrame = screen.frame;
        // Set minimum size to 720p and use screen size directly
        setWindowMinSize(const Size(1280, 720));
        setWindowMaxSize(screenFrame.size);

        // Set to screen size directly
        setWindowFrame(Rect.fromLTWH(
          screenFrame.left,
          screenFrame.top,
          screenFrame.width,
          screenFrame.height,
        ));
      }
    });
  }

  // Initialize sqflite_common_ffi for desktop platforms
  if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    // Initialize database
    final db = await DatabaseHelper().database;
    print('Database initialized successfully');

    // Print database path and contents
    await DbPathPrinter.printPath();
  } catch (e) {
    print('Error initializing database: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isLicensed = false;

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    try {
      final licenseService = await LicenseService.getInstance();
      final storedLicense = await licenseService.getStoredLicense();

      if (storedLicense != null) {
        final isValid = await licenseService.validateLicense(storedLicense);
        setState(() {
          _isLicensed = isValid;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLicensed = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking license: $e');
      setState(() {
        _isLicensed = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Barcode System',
      home: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isLicensed
              ? const LoginPage()
              : const LicenseActivationPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/engineer-login': (context) => const EngineerLogin(),
        '/operator-login': (context) => const OperatorLogin(),
        '/account-settings': (context) => const AccountSettings(),
        '/manage-accounts': (context) => const ManageAccounts(),
        '/new-account': (context) => const NewAccount(),
        '/edit-user': (context) => EditUser(
            user: ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>),
        '/item-masterlist': (context) => const ItemMasterlist(),
        '/register-item': (context) => const RegisterItem(),
        '/revise-item': (context) => ReviseItem(
              item: ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>,
            ),
        '/license-activation': (context) => const LicenseActivationPage(),
      },
    );
  }
}
