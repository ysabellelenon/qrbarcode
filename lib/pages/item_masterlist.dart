import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'login_page.dart';
import '../utils/logout_helper.dart';

class ItemMasterlist extends StatefulWidget {
  const ItemMasterlist({super.key});

  @override
  State<ItemMasterlist> createState() => _ItemMasterlistState();
}

class _ItemMasterlistState extends State<ItemMasterlist> {
  final Set<int> selectedItems = {};
  bool selectAll = false;
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> filteredItems = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadItems();
    searchController.addListener(_filterItems);
  }

  Future<void> _loadItems() async {
    final data = await DatabaseHelper().getItems();
    setState(() {
      items = data;
      filteredItems = data;
    });
  }

  void _filterItems() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredItems = items.where((item) {
        final itemCode = item['itemCode']?.toLowerCase() ?? '';
        return itemCode.contains(query);
      }).toList();
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
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/engineer-login'),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

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
                              // Search Bar and New Register Button
                              Row(
                                children: [
                                  Expanded(
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
                                  const SizedBox(width: 16),
                                  ElevatedButton(
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
                                    onPressed: () => Navigator.pushNamed(context, '/register-item'),
                                    child: const Text('New Register'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Table
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 40,
                                  horizontalMargin: 20,
                                  columns: const [
                                    DataColumn(label: Text('')), // Checkbox column
                                    DataColumn(label: Text('No.')),
                                    DataColumn(label: Text('Item Code')),
                                    DataColumn(label: Text('Rev No.')),
                                    DataColumn(label: Text('No. of Code')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filteredItems.map((item) {
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
                                        DataCell(Text(item['revision'] ?? '')),
                                        DataCell(Text(item['codeCount'] ?? '')),
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

                              // Delete Button
                              if (selectedItems.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _deleteSelectedItems,
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