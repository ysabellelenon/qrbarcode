import 'package:flutter/material.dart';
import '../constants.dart';
import '../database_helper.dart';
import '../pages/scan_item.dart';

class UnfinishedItems extends StatefulWidget {
  const UnfinishedItems({super.key});

  @override
  State<UnfinishedItems> createState() => _UnfinishedItemsState();
}

class _UnfinishedItemsState extends State<UnfinishedItems> {
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
    final data = await DatabaseHelper().getUnfinishedItems();
    setState(() {
      items = data;
      filteredItems = data;
    });
  }

  void _filterItems() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredItems = items.where((item) {
        return item['itemName'].toLowerCase().contains(query) ||
            item['lotNumber'].toLowerCase().contains(query) ||
            item['poNo'].toLowerCase().contains(query);
      }).toList();
    });
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
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/login'),
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  const Center(
                    child: Text(
                      'Unfinished Items',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Table Section
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1200),
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
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 40,
                                      columns: [
                                        DataColumn(
                                          label: Checkbox(
                                            value: selectAll,
                                            onChanged: (bool? value) {
                                              setState(() {
                                                selectAll = value ?? false;
                                                if (selectAll) {
                                                  selectedItems.addAll(
                                                      filteredItems.map(
                                                          (item) => item['id']
                                                              as int));
                                                } else {
                                                  selectedItems.clear();
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                        const DataColumn(
                                            label: Text('Item Name')),
                                        const DataColumn(
                                            label: Text('Lot Number')),
                                        const DataColumn(
                                            label: Text('P.O Number')),
                                        const DataColumn(label: Text('Date')),
                                        const DataColumn(
                                            label: Text('Actions')),
                                      ],
                                      rows: filteredItems.map((item) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Checkbox(
                                                value: selectedItems
                                                    .contains(item['id']),
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      selectedItems.add(
                                                          item['id'] as int);
                                                    } else {
                                                      selectedItems
                                                          .remove(item['id']);
                                                    }
                                                    selectAll = selectedItems
                                                            .length ==
                                                        filteredItems.length;
                                                  });
                                                },
                                              ),
                                            ),
                                            DataCell(Text(item['itemName'])),
                                            DataCell(Text(item['lotNumber'])),
                                            DataCell(Text(item['poNo'])),
                                            DataCell(Text(
                                                DateTime.parse(item['date'])
                                                    .toString())),
                                            DataCell(
                                              OutlinedButton(
                                                onPressed: () {
                                                  // Show details dialog
                                                  _showDetailsDialog(item);
                                                },
                                                child:
                                                    const Text('View Details'),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                                // Delete Selected Button
                                if (selectedItems.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () async {
                                            await DatabaseHelper()
                                                .deleteUnfinishedItems(
                                                    selectedItems.toList());
                                            _loadItems();
                                            setState(() {
                                              selectedItems.clear();
                                              selectAll = false;
                                            });
                                          },
                                          child: const Text('Delete Selected'),
                                        ),
                                      ],
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

  void _showDetailsDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600), // Reduced width
          padding: const EdgeInsets.all(24), // Add padding for better spacing
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'Item Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Item Name', item['itemName']),
                      _buildDetailRow('Lot Number', item['lotNumber']),
                      _buildDetailRow('P.O Number', item['poNo']),
                      _buildDetailRow(
                          'Date', DateTime.parse(item['date']).toString()),
                      _buildDetailRow('Content', item['content']),
                      _buildDetailRow('Quantity', item['quantity']),
                      _buildDetailRow('Remarks', item['remarks']),
                      const SizedBox(height: 16),
                      const Text(
                        'Results Table:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildResultsTable(item['tableData'] as List),
                    ],
                  ),
                ),
              ),

              // Actions
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScanItem(
                            resumeData: {
                              'itemName': item['itemName'],
                              'lotNumber': item['lotNumber'],
                              'poNo': item['poNo'],
                              'content': item['content'],
                              'quantity': item['quantity'],
                              'tableData': item['tableData'],
                              'unfinishedItemId': item['id'],
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Continue Process'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Slightly wider for labels
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable(List tableData) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(50), // No. column
          1: FlexColumnWidth(2), // Content column
          2: FlexColumnWidth(1), // Result column
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            children: const [
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Content',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Result',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          ...tableData.asMap().entries.map((entry) {
            return TableRow(
              children: [
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text((entry.key + 1).toString()),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(entry.value['content'] ?? ''),
                  ),
                ),
                TableCell(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      entry.value['result'] ?? '',
                      style: TextStyle(
                        color: entry.value['result'] == 'Good'
                            ? Colors.green
                            : entry.value['result'] == 'No Good'
                                ? Colors.red
                                : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
