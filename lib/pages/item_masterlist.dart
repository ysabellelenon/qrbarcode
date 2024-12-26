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
  Set<int> expandedItems = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
    searchController.addListener(_filterItems);
  }

  Future<void> _loadItems() async {
    final data = await DatabaseHelper().getItems();
    print('Loaded items from database: $data');
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

  Widget _buildItemRow(Map<String, dynamic> item, int index) {
    List<Map<String, dynamic>> codes =
        (item['codes'] as List<dynamic>).cast<Map<String, dynamic>>();
    bool isSelected = selectedItems.contains(item['id']);
    bool isExpanded = expandedItems.contains(item['id']);

    bool hasCountingCodes = codes.any((code) => code['category'] == 'Counting');
    bool hasSubLotEnabled = codes.any((code) {
      return code['hasSubLot'] == 1 || code['hasSubLot'] == true;
    });

    return Column(
      children: [
        Material(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                if (expandedItems.contains(item['id'])) {
                  expandedItems.remove(item['id']);
                } else {
                  expandedItems.add(item['id']);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
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
                  SizedBox(width: 50, child: Text(index.toString())),
                  Expanded(
                    flex: 2,
                    child: Text(item['itemCode'] ?? ''),
                  ),
                  Expanded(
                    child: Text(item['revision'] ?? ''),
                  ),
                  Expanded(
                    child: Text(
                      hasCountingCodes ? 'Counting' : 'Non-Counting',
                      style: TextStyle(
                        color: hasCountingCodes ? Colors.blue : Colors.cyan,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      hasCountingCodes
                          ? (hasSubLotEnabled ? 'Yes' : 'No')
                          : 'N/A',
                      style: TextStyle(
                        color: hasCountingCodes
                            ? (hasSubLotEnabled ? Colors.green : Colors.red)
                            : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: OutlinedButton(
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
                  ),
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        if (expandedItems.contains(item['id'])) {
                          expandedItems.remove(item['id']);
                        } else {
                          expandedItems.add(item['id']);
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 50.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: codes.map((code) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 16.0),
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          code['category'] ?? '',
                          style: TextStyle(
                            color: code['category'] == 'Counting'
                                ? Colors.blue
                                : Colors.cyan,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(code['content'] ?? ''),
                      ),
                      if (code['category'] == 'Counting')
                        Expanded(
                          child: Text(
                            'Serial Count: ${code['serialCount'] ?? '0'}',
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
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
                      onPressed: () => Navigator.of(context).pushReplacement(
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
                        constraints: const BoxConstraints(maxWidth: 1200),
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
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const RegisterItem(),
                                        ),
                                      ),
                                      child: const Text('New Register'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Header Row
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8.0),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: selectAll,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            selectAll = value ?? false;
                                            if (selectAll) {
                                              selectedItems.clear();
                                              for (var item in items) {
                                                selectedItems
                                                    .add(item['id'] as int);
                                              }
                                            } else {
                                              selectedItems.clear();
                                            }
                                          });
                                        },
                                      ),
                                      const SizedBox(
                                          width: 50, child: Text('No.')),
                                      const Expanded(
                                        flex: 2,
                                        child: Text('Item Name'),
                                      ),
                                      const Expanded(child: Text('REV.')),
                                      const Expanded(child: Text('Category')),
                                      const Expanded(child: Text('Sub-Lot')),
                                      const SizedBox(
                                          width: 100, child: Text('Actions')),
                                      const SizedBox(
                                          width: 48), // For expand icon
                                    ],
                                  ),
                                ),

                                // Item Rows
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, index) {
                                    return _buildItemRow(
                                        filteredItems[index], index + 1);
                                  },
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
                                            borderRadius:
                                                BorderRadius.circular(8),
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
