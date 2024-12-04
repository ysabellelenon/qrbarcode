import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pages/login_page.dart';

class LogoutHelper {
  static void showLogoutConfirmation(BuildContext context) {
    final FocusNode logoutFocusNode = FocusNode();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by clicking outside
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: logoutFocusNode,
          autofocus: true,
          onKey: (RawKeyEvent event) {
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                Navigator.pop(context); // Close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.pop(context); // Cancel
              }
            }
          },
          child: AlertDialog(
            title: const Text('Confirm Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => logoutFocusNode.dispose());
  }
} 