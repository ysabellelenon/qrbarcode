import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import the DatabaseHelper

class ScanItem extends StatefulWidget {
  final String itemName;
  final String poNo;
  final String lotNumber;
  final String content;
  final String qtyPerBox;
  final int operatorScanId;
  final int totalQty;

  const ScanItem({
    Key? key,
    required this.itemName,
    required this.poNo,
    required this.lotNumber,
    required this.content,
    required this.qtyPerBox,
    required this.operatorScanId,
    required this.totalQty,
  }) : super(key: key);

  @override
  _ScanItemState createState() => _ScanItemState();
}

class _ScanItemState extends State<ScanItem> {
  final TextEditingController totalQtyController = TextEditingController();
  final TextEditingController qtyPerBoxController = TextEditingController();
  final TextEditingController inspectionQtyController = TextEditingController();
  final List<Map<String, dynamic>> _tableData = [];
  String? _labelContent; // New variable to hold the fetched label content
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _fetchLabelContent(widget.itemName);
    // Add initial row
    _tableData.add({
      'content': '',
      'result': '',
    });
    // Create initial focus node
    _focusNodes.add(FocusNode());
    
    // Use operatorScanId if necessary
    print('Operator Scan ID: ${widget.operatorScanId}');
    // Set the total quantity from the operator login
    totalQtyController.text = widget.totalQty.toString();
  }

  @override
  void dispose() {
    // Clean up focus nodes
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _fetchLabelContent(String itemName) async {
    // Fetch the label content from the database
    final itemData = await DatabaseHelper().getItems(); // Fetch all items
    final matchingItem = itemData.firstWhere(
      (item) => item['itemCode'] == itemName,
      orElse: () => {}, // Return an empty map instead of null
    );

    if (matchingItem.isNotEmpty) { // Check if matchingItem is not empty
      setState(() {
        _labelContent = matchingItem['codes'].isNotEmpty
            ? matchingItem['codes'][0]['content'] // Get the first code content
            : 'No content available';
      });
    } else {
      setState(() {
        _labelContent = 'Item not found';
      });
    }
  }

  void _addRow() {
    if (qtyPerBoxController.text.isNotEmpty) {
      setState(() {
        _tableData.add({
          'content': '',
          'result': '',
        });
      });
    }
  }

  FocusNode _ensureFocusNode(int index) {
    // Add focus nodes if needed
    while (_focusNodes.length <= index) {
      _focusNodes.add(FocusNode());
    }
    return _focusNodes[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Back Button
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: OutlinedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Back'),
            ),
          ),
          const SizedBox(height: 20),

          // Heading
          const Center(
            child: Text(
              'Scan Item',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 900), // Outer container
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Existing Container for Item Details
                      Padding(
                        padding: const EdgeInsets.all(30),
                        child: Row(
                          children: [
                            // Static Text Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Item Name: ${widget.itemName}', style: const TextStyle(fontSize: 16)),
                                  Text('P.O No: ${widget.poNo}', style: const TextStyle(fontSize: 16)),
                                  Text('Lot Number: ${widget.lotNumber}', style: const TextStyle(fontSize: 16)),
                                  const SizedBox(height: 32),
                                  const Text('Content:', style: TextStyle(fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Text(_labelContent ?? 'No content available', style: const TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20), // Space between sections
                            // Input Fields Section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Total QTY', style: TextStyle(fontSize: 16)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: totalQtyController,
                                          decoration: const InputDecoration(border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'QTY per box (${widget.qtyPerBox})',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: qtyPerBoxController,
                                          decoration: const InputDecoration(border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text('Inspection QTY', style: TextStyle(fontSize: 16)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: inspectionQtyController,
                                          decoration: const InputDecoration(border: OutlineInputBorder()),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20), // Space between containers

                      // Good/No Good Container
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Good', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Enter Good value',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('No Good', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    TextField(
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Enter No Good value',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Results Table Container
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 30), // Add bottom margin
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DataTable(
                            dividerThickness: 1,
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            columns: const [
                              DataColumn(
                                label: SizedBox(
                                  width: 100,
                                  child: Center(child: Text('No.')),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 400,
                                  child: Center(child: Text('Content')),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 200,
                                  child: Center(child: Text('Result')),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 80,
                                  child: Center(child: Text('')),
                                ),
                              ),
                            ],
                            rows: _tableData.asMap().entries.map((entry) {
                              int index = entry.key;
                              Map<String, dynamic> data = entry.value;
                              return DataRow(cells: [
                                DataCell(Text((index + 1).toString())),
                                DataCell(
                                  TextField(
                                    focusNode: _ensureFocusNode(index),
                                    onChanged: (value) {
                                      setState(() {
                                        data['content'] = value;
                                        // Update result based on content
                                        data['result'] = value.isNotEmpty
                                            ? (value == 'Good' ? 'Good' : 'No Good')
                                            : null;
                                      });
                                    },
                                    onSubmitted: (value) {
                                      setState(() {
                                        _tableData.add({
                                          'content': '',
                                          'result': '',
                                        });
                                        // Add new focus node for the new row
                                        _focusNodes.add(FocusNode());
                                        // Request focus on the new row after a brief delay
                                        Future.delayed(const Duration(milliseconds: 100), () {
                                          _focusNodes.last.requestFocus();
                                        });
                                      });
                                    },
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      data['result'] ?? '',
                                      style: TextStyle(
                                        color: data['result'] == 'Good' ? Colors.green : Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        // Remove the focus node for this row
                                        if (index < _focusNodes.length) {
                                          _focusNodes[index].dispose();
                                          _focusNodes.removeAt(index);
                                        }
                                        // Remove the row data
                                        _tableData.removeAt(index);
                                        // Only add a new row if the table becomes empty
                                        if (_tableData.isEmpty) {
                                          _tableData.add({
                                            'content': '',
                                            'result': '',
                                          });
                                          _focusNodes.add(FocusNode());
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ]);
                            }).toList(),
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
    );
  }
}
