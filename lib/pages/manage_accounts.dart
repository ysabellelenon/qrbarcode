import 'package:flutter/material.dart';
import '../constants.dart';
import 'login_page.dart';
import '../database_helper.dart';
import 'edit_user.dart';
import '../utils/logout_helper.dart';

class ManageAccounts extends StatefulWidget {
  const ManageAccounts({super.key});

  @override
  State<ManageAccounts> createState() => _ManageAccountsState();
}

class _ManageAccountsState extends State<ManageAccounts> {
  final Set<int> selectedUsers = {};
  bool selectAll = false;
  List<Map<String, dynamic>> users = [];
  List<Map<String, dynamic>> filteredUsers = [];
  final TextEditingController searchController = TextEditingController();
  int? currentUserId; // Store the current user's ID

  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Load current user when initializing
    _loadUsers();
    searchController.addListener(_filterUsers);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for success message in route arguments
    final message = ModalRoute.of(context)?.settings.arguments as String?;
    if (message != null) {
      // Show success message after build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      });
    }
  }

  Future<void> _loadUsers() async {
    final db = await DatabaseHelper().database;
    final data = await db.query('users',
        where: 'username NOT IN (?)', whereArgs: ['dev_operator']);
    setState(() {
      users = data;
      filteredUsers = data;
    });
  }

  Future<void> _loadCurrentUser() async {
    final currentUserId = await DatabaseHelper().getCurrentUserId();
    setState(() {
      this.currentUserId = currentUserId;
    });
  }

  void _filterUsers() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredUsers = users.where((user) {
        final fullName =
            '${user['firstName']} ${user['middleName']} ${user['lastName']}'
                .toLowerCase();
        return fullName.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteSelectedUsers() async {
    try {
      // Get the IDs of selected users
      final selectedIds = selectedUsers.toList();

      // Get current user ID
      final currentId = await DatabaseHelper().getCurrentUserId();

      // Safety check - don't delete if current user is in selection
      if (currentId != null && selectedIds.contains(currentId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot delete your own account'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Delete from database
      final db = await DatabaseHelper().database;
      await db.delete(
        'users',
        where: 'id IN (${List.filled(selectedIds.length, '?').join(',')})',
        whereArgs: selectedIds,
      );

      // Refresh the users list
      await _loadUsers();

      setState(() {
        selectedUsers.clear();
        selectAll = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Users deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting users: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            child: Container(
              color: kBackgroundColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  OutlinedButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/account-settings'),
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
                                  controller: searchController,
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
                                              selectedUsers.clear();
                                              for (var user in filteredUsers) {
                                                if (user['id'] !=
                                                    currentUserId) {
                                                  // Don't select current user
                                                  selectedUsers
                                                      .add(user['id'] as int);
                                                }
                                              }
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
                                  rows: List<DataRow>.generate(
                                    filteredUsers.length,
                                    (index) {
                                      final user = filteredUsers[index];
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Checkbox(
                                              value: selectedUsers
                                                  .contains(user['id']),
                                              onChanged: user['id'] ==
                                                      currentUserId
                                                  ? null // Disable checkbox for current user
                                                  : (bool? value) {
                                                      setState(() {
                                                        if (value == true) {
                                                          selectedUsers.add(
                                                              user['id']
                                                                  as int);
                                                          if (selectedUsers
                                                                  .length ==
                                                              filteredUsers
                                                                      .length -
                                                                  1) {
                                                            // -1 to account for current user
                                                            selectAll = true;
                                                          }
                                                        } else {
                                                          selectedUsers.remove(
                                                              user['id']
                                                                  as int);
                                                          selectAll = false;
                                                        }
                                                      });
                                                    },
                                            ),
                                          ),
                                          DataCell(Text('${index + 1}')),
                                          DataCell(Text(user['lastName'])),
                                          DataCell(Text(user['firstName'])),
                                          DataCell(Text(user['lineNo'])),
                                          DataCell(Text(user['section'])),
                                          DataCell(
                                            OutlinedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        EditUser(user: user),
                                                  ),
                                                );
                                              },
                                              child: const Text('Edit'),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // Delete Selected Button
                              if (selectedUsers.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 32),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _deleteSelectedUsers,
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
