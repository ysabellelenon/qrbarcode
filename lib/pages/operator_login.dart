import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import database helper
import '../pages/article_label.dart'; // Import the new ArticleLabel page
import 'dart:async';

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
  List<String> _labelContents = [];
  bool _isItemFound = false;

  // Add FocusNode for each text field
  final _itemNameFocus = FocusNode();
  final _poNoFocus = FocusNode();
  final _qtyFocus = FocusNode();

  Timer? _poNoTimer;

  @override
  void initState() {
    super.initState();
    // Request focus for the item name field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_itemNameFocus);
    });
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _poNoController.dispose();
    _qtyController.dispose();
    // Dispose focus nodes
    _itemNameFocus.dispose();
    _poNoFocus.dispose();
    _qtyFocus.dispose();
    // Cancel timer if exists
    _poNoTimer?.cancel();
    super.dispose();
  }

  void _fetchLabelContent(String itemName) async {
    final itemData = await DatabaseHelper().getItems();
    final matchingItem = itemData.firstWhere(
      (item) => item['itemCode'] == itemName,
      orElse: () => {},
    );

    if (mounted) {
      setState(() {
        if (matchingItem.isNotEmpty && matchingItem['codes']?.isNotEmpty == true) {
          // Get all codes and their contents
          _labelContents = (matchingItem['codes'] as List)
              .map((code) => code['content'].toString())
              .toList();
          _isItemFound = true;
          // Add a small delay before moving focus to ensure UI is updated
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _isItemFound) {
              FocusScope.of(context).unfocus(); // First unfocus current field
              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted) {
                  FocusScope.of(context).requestFocus(_poNoFocus);
                }
              });
            }
          });
        } else {
          _labelContents = ['Item not found'];
          _isItemFound = false;
        }
      });
    }
  }

  void _handlePoNoInput(String value) {
    // Wait for a short delay to ensure complete scan
    if (value.isNotEmpty) {
      // Cancel any previous timer
      _poNoTimer?.cancel();
      // Start a new timer
      _poNoTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          FocusScope.of(context).unfocus(); // First unfocus current field
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              FocusScope.of(context).requestFocus(_qtyFocus);
            }
          });
        }
      });
    }
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate() && _isItemFound) {
      final itemName = _itemNameController.text;
      final poNo = _poNoController.text;
      final totalQty = int.parse(_qtyController.text);

      // Save the operator scan to database
      final operatorScanId = await DatabaseHelper().insertOperatorScan({
        'itemName': itemName,
        'poNo': poNo,
        'totalQty': totalQty,
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
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
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/login'),
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
                                    validator: (value) {
                                      if (value!.isEmpty) return 'Required';
                                      if (!_isItemFound)
                                        return 'Item not found';
                                      return null;
                                    },
                                    onChanged: (value) {
                                      _fetchLabelContent(value);
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
                                    validator: (value) =>
                                        value!.isEmpty ? 'Required' : null,
                                    onChanged: _handlePoNoInput,
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
                                    validator: (value) =>
                                        value!.isEmpty ? 'Required' : null,
                                    onFieldSubmitted: (_) {
                                      _handleSubmit();
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: SelectableText(
                                      'Contents:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.normal,
                                        color: Color(0xFF2C3E50),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _labelContents.map((content) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: SelectableText(
                                          content,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            height: 1.5,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    onPressed:
                                        _isItemFound ? _handleSubmit : null,
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
                                      disabledBackgroundColor: Colors.grey,
                                    ),
                                    child: const Text('Ok'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
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
