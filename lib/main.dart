import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/engineer_login.dart';
import 'pages/account_settings.dart';
import 'pages/manage_accounts.dart';
import 'pages/new_account.dart';
import 'pages/edit_user.dart';
import 'pages/item_masterlist.dart';
import 'pages/register_item.dart';
import 'pages/sublot_config.dart';
import 'pages/review_item.dart';
import 'pages/revise_item.dart';
import 'pages/operator_login.dart';
import 'pages/scan_item.dart';
import 'database_helper.dart';
import 'utils/db_path_printer.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final dbHelper = DatabaseHelper();
  await dbHelper.database;
  await DbPathPrinter.printPath();
  
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
      onGenerateRoute: (settings) {
        if (settings.name == '/scan-item') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ScanItem(
              itemName: args['itemName'],
              poNo: args['poNo'],
              lotNumber: args['lotNumber'],
              content: args['content'],
              qtyPerBox: args['qtyPerBox'],
              operatorScanId: args['operatorScanId'],
            ),
          );
        }
        
        // Handle other routes
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (context) => const LoginPage());
          case '/engineer-login':
            return MaterialPageRoute(builder: (context) => const EngineerLogin());
          case '/operator-login':
            return MaterialPageRoute(builder: (context) => const OperatorLogin());
          case '/account-settings':
            return MaterialPageRoute(builder: (context) => const AccountSettings());
          case '/manage-accounts':
            return MaterialPageRoute(builder: (context) => const ManageAccounts());
          case '/new-account':
            return MaterialPageRoute(builder: (context) => const NewAccount());
          case '/edit-user':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => EditUser(user: args),
            );
          case '/item-masterlist':
            return MaterialPageRoute(builder: (context) => const ItemMasterlist());
          case '/register-item':
            return MaterialPageRoute(builder: (context) => const RegisterItem());
          case '/sublot-config':
            return MaterialPageRoute(
              builder: (context) => SublotConfig(
                itemName: '',
                countingCodes: const <Map<String, String>>[],
              ),
            );
          case '/review-item':
            return MaterialPageRoute(
              builder: (context) => ReviewItem(
                itemName: '',
                revision: '',
                codeCount: 0,
                codes: [],
              ),
            );
          case '/revise-item':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ReviseItem(item: args),
            );
          default:
            return null;
        }
      },
    );
  }
}
