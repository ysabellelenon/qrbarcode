import 'package:flutter/material.dart';
import '../constants.dart';
import 'login_page.dart';

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key});

  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  final Set<String> selectedUsers = {};
  bool selectAll = false;

  final List<Map<String, String>> users = [
    {
      'no': '1',
      'lastName': 'User',
      'firstName': 'Test',
      'lineNo': 'Admin',
      'section': 'A',
    },
    {
      'no': '2',
      'lastName': 'User',
      'firstName': 'Assembly',
      'lineNo': 'Assembly',
      'section': 'B',
    },
    {
      'no': '3',
      'lastName': 'Lenon',
      'firstName': 'Ricky',
      'lineNo': 'Admin',
      'section': 'Engineering',
    },
  ];

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

                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Users Table
                  Expanded(
                    child: Card(
                      color: Colors.white,
                      elevation: 4,
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            DataColumn(
                              label: Checkbox(
                                value: selectAll,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectAll = value ?? false;
                                    if (selectAll) {
                                      // Select all users
                                      selectedUsers.addAll(users.map((user) => user['no']!));
                                    } else {
                                      // Deselect all users
                                      selectedUsers.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                            const DataColumn(
                              label: Text('No.'),
                            ),
                            const DataColumn(
                              label: Text('Last Name'),
                            ),
                            const DataColumn(
                              label: Text('First Name'),
                            ),
                            const DataColumn(
                              label: Text('Line No.'),
                            ),
                            const DataColumn(
                              label: Text('Section'),
                            ),
                            const DataColumn(
                              label: Text('Actions'),
                            ),
                          ],
                          rows: users.map((user) {
                            return DataRow(
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: selectedUsers.contains(user['no']),
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedUsers.add(user['no']!);
                                          // Update selectAll if all users are selected
                                          if (selectedUsers.length == users.length) {
                                            selectAll = true;
                                          }
                                        } else {
                                          selectedUsers.remove(user['no']!);
                                          // Update selectAll when any user is deselected
                                          selectAll = false;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(Text(user['no']!)),
                                DataCell(Text(user['lastName']!)),
                                DataCell(Text(user['firstName']!)),
                                DataCell(Text(user['lineNo']!)),
                                DataCell(Text(user['section']!)),
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
                    ),
                  ),

                  // Delete Selected Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: selectedUsers.isEmpty
                            ? null  // Disable button if no users are selected
                            : () {
                                // Add delete functionality
                                setState(() {
                                  users.removeWhere((user) => selectedUsers.contains(user['no']));
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
        ],
      ),
    );
  }
} 