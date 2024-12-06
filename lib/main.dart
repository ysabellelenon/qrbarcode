import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // Import sqflite_common_ffi
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
import 'database_helper.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Barcode System',
      home: const LoginPage(),
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
      },
    );
  }
}
