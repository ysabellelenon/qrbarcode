import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import database helper
import '../pages/article_label.dart'; // Import the new ArticleLabel page
import '../pages/unfinished_items.dart'; // Import the new UnfinishedItems page

class OperatorLogin extends StatefulWidget {
  const OperatorLogin({super.key});

  @override
  State<OperatorLogin> createState() => _OperatorLoginState();
}

class _OperatorLoginState extends State<OperatorLogin> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _poNoController = TextEditingController();
  final _qtyController = TextEditingController();
  String? _labelContent; // New variable to hold the fetched label content

  // Add FocusNode for each text field
  final _itemNameFocus = FocusNode();
  final _poNoFocus = FocusNode();
  final _qtyFocus = FocusNode();

  @override
  void dispose() {
    _itemNameController.dispose();
    _poNoController.dispose();
    _qtyController.dispose();
    // Dispose focus nodes
    _itemNameFocus.dispose();
    _poNoFocus.dispose();
    _qtyFocus.dispose();
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

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final itemName = _itemNameController.text;
      final poNo = _poNoController.text;
      final totalQty = int.parse(_qtyController.text);

      // Save the operator scan to database
      final operatorScanId = await DatabaseHelper().insertOperatorScan({
        'itemName': itemName,
        'poNo': poNo,
        'totalQty': totalQty,
        'content': _labelContent ?? '',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        // Navigate to ArticleLabel page with all required parameters
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ArticleLabel(
              itemName: itemName,
              poNo: poNo,
              operatorScanId: operatorScanId,
              totalQty: totalQty,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Scan P.O and Item Name',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 4,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    controller: _itemNameController,
                                    focusNode: _itemNameFocus,
                                    decoration: const InputDecoration(
                                      labelText: 'Item Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Required' : null,
                                    onChanged: (value) {
                                      _fetchLabelContent(value);
                                    },
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(context).requestFocus(_poNoFocus);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _poNoController,
                                    focusNode: _poNoFocus,
                                    decoration: const InputDecoration(
                                      labelText: 'P.O No.',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) => value!.isEmpty ? 'Required' : null,
                                    onFieldSubmitted: (_) {
                                      FocusScope.of(context).requestFocus(_qtyFocus);
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _qtyController,
                                    focusNode: _qtyFocus,
                                    decoration: const InputDecoration(
                                      labelText: 'Total QTY',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) => value!.isEmpty ? 'Required' : null,
                                    onFieldSubmitted: (_) {
                                      _handleSubmit();
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Content:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(_labelContent ?? 'No content available'), // Display the label content
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed: _handleSubmit,
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
                                    child: const Text('Ok'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const UnfinishedItems(),
                                ),
                              );
                            },
                            child: const Text('View Unfinished Items'),
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
    );
  }
} 