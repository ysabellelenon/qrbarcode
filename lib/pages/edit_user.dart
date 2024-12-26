import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart';
import '../database_helper.dart';
import '../utils/logout_helper.dart';

class EditUser extends StatefulWidget {
  final Map<String, dynamic> user;
  
  const EditUser({super.key, required this.user});

  @override
  State<EditUser> createState() => _EditUserState();
}

class _EditUserState extends State<EditUser> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _surnameController;
  late TextEditingController _sectionController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing user data
    _firstNameController = TextEditingController(text: widget.user['firstName']);
    _middleNameController = TextEditingController(text: widget.user['middleName']);
    _surnameController = TextEditingController(text: widget.user['lastName']);
    _sectionController = TextEditingController(text: widget.user['section']);
    _usernameController = TextEditingController(text: widget.user['username']);
    _passwordController = TextEditingController(text: widget.user['password']);
    _selectedCategory = widget.user['lineNo'];
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _surnameController.dispose();
    _sectionController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleUpdate() async {
    if (_formKey.currentState!.validate()) {
      final updatedUser = {
        'id': widget.user['id'],
        'firstName': _firstNameController.text,
        'middleName': _middleNameController.text,
        'lastName': _surnameController.text,
        'section': _sectionController.text,
        'lineNo': _selectedCategory,
        'username': _usernameController.text,
        'password': _passwordController.text,
      };

      try {
        await DatabaseHelper().updateUser(updatedUser);
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/manage-accounts',
            arguments: 'Account updated successfully',
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating account: $e'),
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
                  onPressed: () => LogoutHelper.showLogoutConfirmation(context),
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
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),
                  
                  const Center(
                    child: Text(
                      'Edit Account',
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
                                            keyboardType: TextInputType.number,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
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
                                    onPressed: _handleUpdate,
                                    child: const Text('Update'),
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
    );
  }
} 