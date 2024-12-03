import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling

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
                  constraints: const BoxConstraints(maxWidth: 600),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Item Name: ${widget.itemName}', style: const TextStyle(fontSize: 18)),
                        Text('P.O No: ${widget.poNo}', style: const TextStyle(fontSize: 18)),
                        Text('Lot Number: ${widget.lotNumber}', style: const TextStyle(fontSize: 18)),
                        Text('Content: ${widget.content}', style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 32),

                        // Input fields
                        TextField(
                          controller: totalQtyController,
                          decoration: const InputDecoration(labelText: 'Total QTY', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: qtyPerBoxController,
                          decoration: const InputDecoration(labelText: 'QTY per box', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: inspectionQtyController,
                          decoration: const InputDecoration(labelText: 'Inspection QTY', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 32),

                        // Add Row Button
                        ElevatedButton(
                          onPressed: _addRow,
                          child: const Text('Add Row'),
                        ),
                        const SizedBox(height: 20),

                        // Table
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('No.')),
                            DataColumn(label: Text('Content')),
                            DataColumn(label: Text('Result')),
                          ],
                          rows: _tableData.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> row = entry.value;
                            return DataRow(cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(
                                TextField(
                                  onChanged: (value) {
                                    setState(() {
                                      row['content'] = value;
                                      row['result'] = value.isNotEmpty ? 'Good' : '';
                                    });
                                  },
                                  decoration: const InputDecoration(border: OutlineInputBorder()),
                                ),
                              ),
                              DataCell(Text(row['result'] ?? '')),
                            ]);
                          }).toList(),
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
