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
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper().database;
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
        '/account-settings': (context) => const AccountSettings(),
        '/manage-accounts': (context) => const ManageAccounts(),
        '/new-account': (context) => const NewAccount(),
        '/edit-user': (context) => EditUser(
          user: ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>
        ),
        '/item-masterlist': (context) => const ItemMasterlist(),
        '/register-item': (context) => const RegisterItem(),
        '/sublot-config': (context) => SublotConfig(
          itemName: '',
          countingCodes: const <Map<String, String>>[],
        ),
        '/review-item': (context) => ReviewItem(
          itemName: '',
          revision: '',
          codeCount: 0,
          codes: [],
        ),
      },
    );
  }
}
