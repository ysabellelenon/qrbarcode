import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'login_page.dart';

class ItemMasterlist extends StatefulWidget {
  const ItemMasterlist({super.key});

  @override
  State<ItemMasterlist> createState() => _ItemMasterlistState();
}

class _ItemMasterlistState extends State<ItemMasterlist> {
  final Set<int> selectedItems = {};
  bool selectAll = false;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await DatabaseHelper().getItems();
    setState(() {
      items = data;
    });
  }

  Future<void> _deleteSelectedItems() async {
    try {
      await DatabaseHelper().deleteItems(selectedItems.toList());
      setState(() {
        items.removeWhere((item) => selectedItems.contains(item['id']));
        selectedItems.clear();
        selectAll = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Items deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
              child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
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
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _showLogoutConfirmation(context);
                      },
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Title
                  const Center(
                    child: Text(
                      'Item Masterlist',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Table Section with Search and Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Search Bar
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            // Implement search functionality
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // New Register Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () {
                          // Navigate to new item registration page
                        },
                        child: const Text('New Register'),
                      ),
                      // Delete Button (visible only when items are selected)
                      if (selectedItems.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          onPressed: _deleteSelectedItems,
                          child: const Text('Delete'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Table or Empty State
                  Expanded(
                    child: items.isEmpty
                        ? const Center(
                            child: Text(
                              'No items available. Please add new items.',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : SingleChildScrollView(
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
                                          selectedItems.addAll(
                                            items.map((item) => item['id'] as int),
                                          );
                                        } else {
                                          selectedItems.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const DataColumn(label: Text('No.')),
                                const DataColumn(label: Text('Item Code')),
                                const DataColumn(label: Text('Description')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: items.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: selectedItems.contains(item['id']),
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              selectedItems.add(item['id'] as int);
                                            } else {
                                              selectedItems.remove(item['id']);
                                            }
                                            selectAll = selectedItems.length == items.length;
                                          });
                                        },
                                      ),
                                    ),
                                    DataCell(Text(item['id'].toString())),
                                    DataCell(Text(item['itemCode'] ?? '')),
                                    DataCell(Text(item['description'] ?? '')),
                                    DataCell(
                                      OutlinedButton(
                                        onPressed: () {
                                          // Navigate to edit item page
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 