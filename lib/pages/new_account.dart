import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../database_helper.dart';

class NewAccount extends StatefulWidget {
  const NewAccount({super.key});

  @override
  State<NewAccount> createState() => _NewAccountState();
}

class _NewAccountState extends State<NewAccount> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _sectionController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedCategory = 'Assembly';

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _surnameController.dispose();
    _sectionController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passwords do not match!'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
      return true;
    }
    return false;
  }

  void _handleSubmit() async {
    if (_validateForm()) {
      final user = {
        'firstName': _firstNameController.text,
        'middleName': _middleNameController.text,
        'lastName': _surnameController.text,
        'section': _sectionController.text,
        'lineNo': _selectedCategory,
        'username': _usernameController.text,
        'password': _passwordController.text,
      };
      
      try {
        await DatabaseHelper().insertUser(user);
        if (mounted) {
          Navigator.pushReplacementNamed(
            context, 
            '/manage-accounts',
            arguments: 'Account successfully created',
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating account: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          _handleSubmit();
        }
      },
      child: Scaffold(
        backgroundColor: kBackgroundColor,
        body: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'QR Barcode System',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/account-settings'),
                      child: const Text('Back'),
                    ),
                    const SizedBox(height: 20),
                    
                    const Center(
                      child: Text(
                        'New Account Registration',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Card(
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Two cards in a row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Personal Information Section
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Personal Information',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            TextFormField(
                                              controller: _firstNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'First Name',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _middleNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Middle Name',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _surnameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Surname',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _sectionController,
                                              decoration: const InputDecoration(
                                                labelText: 'Section',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 32),

                                      // Account Details Section
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Account Details',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2C3E50),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            TextFormField(
                                              controller: _usernameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Username',
                                                border: OutlineInputBorder(),
                                              ),
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            DropdownButtonFormField<String>(
                                              value: _selectedCategory.isEmpty ? null : _selectedCategory,
                                              decoration: const InputDecoration(
                                                labelText: 'Category',
                                                border: OutlineInputBorder(),
                                              ),
                                              items: const [
                                                DropdownMenuItem(
                                                  value: 'Admin',
                                                  child: Text('Admin'),
                                                ),
                                                DropdownMenuItem(
                                                  value: 'Assembly',
                                                  child: Text('Assembly'),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedCategory = value!;
                                                });
                                              },
                                              validator: (value) => value == null ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _passwordController,
                                              decoration: const InputDecoration(
                                                labelText: 'Password',
                                                border: OutlineInputBorder(),
                                              ),
                                              obscureText: true,
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                            const SizedBox(height: 16),
                                            TextFormField(
                                              controller: _confirmPasswordController,
                                              decoration: const InputDecoration(
                                                labelText: 'Confirm Password',
                                                border: OutlineInputBorder(),
                                              ),
                                              obscureText: true,
                                              validator: (value) => value!.isEmpty ? 'Required' : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),

                                  // Save Button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _handleSubmit,
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 