import 'package:flutter/material.dart';
import '../constants.dart';
import 'login_page.dart';
import '../database_helper.dart';

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key});

  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  final Set<int> selectedUsers = {};
  bool selectAll = false;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final data = await DatabaseHelper().getUsers();
    setState(() {
      users = data;
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
                Navigator.pop(context);
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
        );
      },
    );
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
                  onPressed: () => _showLogoutConfirmation(context),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              color: kBackgroundColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

                  // Registered Users Title
                  const Center(
                    child: Text(
                      'Registered Users',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Table Section with Search and Delete Button
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Card(
                        color: Colors.white,
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Search Bar
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search...',
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(Icons.search),
                                  ),
                                ),
                              ),

                              // Table
                              SingleChildScrollView(
                                child: DataTable(
                                  columnSpacing: 40,
                                  horizontalMargin: 20,
                                  columns: [
                                    DataColumn(
                                      label: Checkbox(
                                        value: selectAll,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            selectAll = value ?? false;
                                            if (selectAll) {
                                              selectedUsers.addAll(users.map((user) => user['id'] as int));
                                            } else {
                                              selectedUsers.clear();
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const DataColumn(label: Text('No.')),
                                    const DataColumn(label: Text('Last Name')),
                                    const DataColumn(label: Text('First Name')),
                                    const DataColumn(label: Text('Line No.')),
                                    const DataColumn(label: Text('Section')),
                                    const DataColumn(label: Text('Actions')),
                                  ],
                                  rows: users.map((user) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: selectedUsers.contains(user['id']),
                                            onChanged: (bool? value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedUsers.add(user['id'] as int);
                                                  if (selectedUsers.length == users.length) {
                                                    selectAll = true;
                                                  }
                                                } else {
                                                  selectedUsers.remove(user['id'] as int);
                                                  selectAll = false;
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        DataCell(Text(user['id'].toString())),
                                        DataCell(Text(user['lastName'])),
                                        DataCell(Text(user['firstName'])),
                                        DataCell(Text(user['lineNo'])),
                                        DataCell(Text(user['section'])),
                                        DataCell(
                                          OutlinedButton(
                                            onPressed: () {
                                              // Add edit functionality
                                            },
                                            child: const Text('Edit'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),

                              // Delete Selected Button
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 16),
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
                                    onPressed: selectedUsers.isEmpty
                                        ? null
                                        : () {
                                            setState(() {
                                              users.removeWhere(
                                                  (user) => selectedUsers.contains(user['id'] as int));
                                              selectedUsers.clear();
                                            });
                                          },
                                    child: const Text('Delete Selected'),
                                  ),
                                ),
                              ),
                            ],
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