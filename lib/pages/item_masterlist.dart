import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import 'login_page.dart';
import '../utils/logout_helper.dart';
import 'revise_item.dart';
import 'engineer_login.dart';
import 'register_item.dart';

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
        filteredItems.removeWhere((item) => selectedItems.contains(item['id']));
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

  List<DataRow> _buildDataRows() {
    List<DataRow> dataRows = [];
    int index = 1;
    for (var item in filteredItems) {
      List<Map<String, dynamic>> codes =
          (item['codes'] as List<dynamic>).cast<Map<String, dynamic>>();
      bool isSelected = selectedItems.contains(item['id']);
      String firstLabel = codes.isNotEmpty
          ? (codes[0]['content']?.trim() ?? '')
          : '';

      for (int i = 0; i < codes.length; i++) {
        var code = codes[i];
        bool isFirstRow = i == 0;

        dataRows.add(
          DataRow(
            cells: [
              DataCell(
                Checkbox(
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedItems.add(item['id']);
                      } else {
                        selectedItems.remove(item['id']);
                      }
                    });
                  },
                ),
              ),
              isFirstRow
                  ? DataCell(Text(index.toString()))
                  : const DataCell(Text('')),
              isFirstRow
                  ? DataCell(Text(item['itemCode'] ?? ''))
                  : const DataCell(Text('')),
              isFirstRow
                  ? DataCell(Text(item['revision'] ?? ''))
                  : const DataCell(Text('')),
              DataCell(
                code['category'] == 'Counting'
                    ? Text('Counting',
                        style: const TextStyle(color: Colors.blue))
                    : Text('Non-Counting',
                        style: const TextStyle(color: Colors.cyan)),
              ),
              DataCell(Text(code['content'] ?? '')),
              isFirstRow
                  ? DataCell(
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReviseItem(item: item),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                          side: const BorderSide(color: Colors.deepPurple),
                        ),
                        child: const Text('Revise'),
                      ),
                    )
                  : const DataCell(Text('')),
            ],
          ),
        );
      }
      index++;
    }
    return dataRows;
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
              child: Container(
                color: kBackgroundColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (context) => const EngineerLogin(),
                            ),
                          ),
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
                                      onPressed: () =>
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const RegisterItem(),
                                            ),
                                          ),
                                      child: const Text('New Register'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Table
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: DataTable(
                                      dataRowMinHeight: 50,
                                      dataRowMaxHeight: 100,
                                      columnSpacing: 20,
                                      horizontalMargin: 20,
                                      columns: [
                                        DataColumn(
                                          label: Checkbox(
                                            value: selectAll,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                selectAll = value ?? false;
                                                if (selectAll) {
                                                  selectedItems.clear();
                                                  for (var item in items) {
                                                    selectedItems.add(item['id'] as int);
                                                  }
                                                } else {
                                                  selectedItems.clear();
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const DataColumn(label: Text('No.')),
                                        const DataColumn(label: Text('Item Name')),
                                        const DataColumn(label: Text('REV.')),
                                        const DataColumn(label: Text('Category')),
                                        const DataColumn(label: Text('Label Content')),
                                        const DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _buildDataRows(),
                                    ),
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
          ),
        ],
      ),
    );
  }
}