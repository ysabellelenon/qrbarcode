import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import the DatabaseHelper

class ScanItem extends StatefulWidget {
  final String itemName;
  final String poNo;
  final String lotNumber;
  final String content;

  const ScanItem({
    Key? key,
    required this.itemName,
    required this.poNo,
    required this.lotNumber,
    required this.content,
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

  @override
  void initState() {
    super.initState();
    _fetchLabelContent(widget.itemName); // Fetch label content on initialization
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
                  constraints: const BoxConstraints(maxWidth: 900),
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
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Row(
                      children: [
                        // Static Text Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Item Name: ${widget.itemName}', style: const TextStyle(fontSize: 18)),
                              Text('P.O No: ${widget.poNo}', style: const TextStyle(fontSize: 18)),
                              Text('Lot Number: ${widget.lotNumber}', style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 32),
                              const Text('Content:', style: TextStyle(fontSize: 18)),
                              const SizedBox(height: 8),
                              Text(_labelContent ?? 'No content available', style: const TextStyle(fontSize: 18)),
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
                                    child: Text('Total QTY', style: TextStyle(fontSize: 18)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: totalQtyController,
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('QTY per box', style: TextStyle(fontSize: 18)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: qtyPerBoxController,
                                      decoration: const InputDecoration(border: OutlineInputBorder()),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text('Inspection QTY', style: TextStyle(fontSize: 18)),
                                  ),
                                  Expanded(
                                    flex: 2,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
