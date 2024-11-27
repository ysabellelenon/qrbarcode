import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/engineer_login.dart';
import 'pages/account_settings.dart';
import 'pages/manage_accounts.dart';

const Color kBackgroundColor = Color(0xFFF5F5F5); // Replace with the color from engineer_login

void main() {
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
      },
    );
  }
}
