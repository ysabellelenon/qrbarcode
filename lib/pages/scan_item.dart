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
  final TextEditingController goodCountController = TextEditingController();
  final TextEditingController noGoodCountController = TextEditingController();
  final List<Map<String, dynamic>> _tableData = [];
  String? _labelContent; // New variable to hold the fetched label content
  String? _itemCategory; // To store the item's category
  final Set<String> _usedContents = {}; // To track used contents for "Counting" category
  final List<FocusNode> _focusNodes = [];
  final Set<int> selectedRows = {};
  bool _isQtyPerBoxReached = false;

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
    // Initialize with '0'
    goodCountController.text = '0';
    noGoodCountController.text = '0';
  }

  @override
  void dispose() {
    // Clean up focus nodes
    for (var node in _focusNodes) {
      node.dispose();
    }
    goodCountController.dispose();
    noGoodCountController.dispose();
    super.dispose();
  }

  void _fetchLabelContent(String itemName) async {
    final itemData = await DatabaseHelper().getItems();
    final matchingItem = itemData.firstWhere(
      (item) => item['itemCode'] == itemName,
      orElse: () => {},
    );

    if (matchingItem.isNotEmpty) {
      setState(() {
        if (matchingItem['codes'].isNotEmpty) {
          _labelContent = matchingItem['codes'][0]['content'];
          _itemCategory = matchingItem['codes'][0]['category'];
        } else {
          _labelContent = 'No content available';
          _itemCategory = null;
        }
      });
    } else {
      setState(() {
        _labelContent = 'Item not found';
        _itemCategory = null;
      });
    }
  }

  String _validateContent(String content, int rowIndex) {
    if (_itemCategory == null || _labelContent == null) {
      print('Category or label content is null');
      return '';
    }

    print('Validating content: $content');
    print('Category: $_itemCategory');
    print('Label Content: $_labelContent');
    print('Row Index: $rowIndex');

    if (_itemCategory == 'Non-Counting') {
      bool isGood = content == _labelContent;
      print('Non-Counting result: ${isGood ? "Good" : "No Good"}');
      return isGood ? 'Good' : 'No Good';
    } else if (_itemCategory == 'Counting') {
      // For first row, content should be different from label content
      if (rowIndex == 0) {
        bool isGood = content != _labelContent;
        if (isGood) {
          _usedContents.add(content);
        }
        print('Counting first row result: ${isGood ? "Good" : "No Good"}');
        return isGood ? 'Good' : 'No Good';
      }
      
      // For subsequent rows:
      // 1. Check if content is already used in previous rows
      if (_usedContents.contains(content)) {
        print('Duplicate content found');
        return 'No Good';
      }
      
      // 2. Content should be different from static content
      if (content == _labelContent) {
        print('Content matches static label');
        return 'No Good';
      }
      
      // 3. Content should be different from all previous contents
      bool isGood = true;
      for (var i = 0; i < rowIndex; i++) {
        if (_tableData[i]['content'] == content) {
          isGood = false;
          break;
        }
      }
      
      if (isGood) {
        _usedContents.add(content);
      }
      print('Counting subsequent row result: ${isGood ? "Good" : "No Good"}');
      return isGood ? 'Good' : 'No Good';
    }
    
    print('No category match found');
    return '';
  }

  void _addRow() {
    if (qtyPerBoxController.text.isNotEmpty) {
      setState(() {
        _tableData.add({
          'content': '',
          'result': '',
        });
        _updateCounts();
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

  void _updateCounts() {
    int goodCount = 0;
    int noGoodCount = 0;

    for (var data in _tableData) {
      if (data['result'] == 'Good') {
        goodCount++;
      } else if (data['result'] == 'No Good') {
        noGoodCount++;
      }
    }

    setState(() {
      goodCountController.text = goodCount.toString();
      noGoodCountController.text = noGoodCount.toString();
      inspectionQtyController.text = (goodCount + noGoodCount).toString();
      qtyPerBoxController.text = _tableData.length.toString();

      // Check if QTY per box limit is reached
      if (_tableData.length == int.parse(widget.qtyPerBox) && !_isQtyPerBoxReached) {
        _isQtyPerBoxReached = true;
        _showQtyReachedDialog();
      }
    });
  }

  void _showQtyReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Information'),
          content: const Text('QTY per box has been reached'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('End Session'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/operator-login');
                },
                child: const Text('Scan New P.O and Item Name'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ArticleLabel(
                        operatorScanId: widget.operatorScanId,
                      ),
                    ),
                  );
                },
                child: const Text('Scan New Article Label'),
              ),
            ],
          ),
        );
      },
    );
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
                  constraints: const BoxConstraints(maxWidth: 1200), // Increased from 900
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
                                          readOnly: true, // Make it read-only
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
                                          readOnly: true, // Make it read-only
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
                          width: 700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: goodCountController,
                                  textAlign: TextAlign.center,
                                  readOnly: true, // Make it read-only
                                  decoration: const InputDecoration(
                                    labelText: 'Good',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16), // Reduced spacing between inputs
                              SizedBox(
                                width: 200,
                                child: TextField(
                                  controller: noGoodCountController,
                                  textAlign: TextAlign.center,
                                  readOnly: true, // Make it read-only
                                  decoration: const InputDecoration(
                                    labelText: 'No Good',
                                    border: OutlineInputBorder(),
                                  ),
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
                          margin: const EdgeInsets.only(bottom: 30),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DataTable(
                            dividerThickness: 1,
                            border: TableBorder(
                              verticalInside: BorderSide(width: 1, color: Colors.grey.shade300),
                              horizontalInside: BorderSide(width: 1, color: Colors.grey.shade300),
                              left: BorderSide(width: 1, color: Colors.grey.shade300),
                              right: BorderSide(width: 1, color: Colors.grey.shade300),
                              top: BorderSide(width: 1, color: Colors.grey.shade300),
                              bottom: BorderSide(width: 1, color: Colors.grey.shade300),
                            ),
                            columns: const [
                              DataColumn(
                                label: SizedBox(
                                  width: 50,
                                  child: Center(child: Text('')), // For checkbox
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 50,
                                  child: Center(child: Text('No.')),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 400, // Increased from 400
                                  child: Center(child: Text('Content')),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: 170, // Increased from 200
                                  child: Center(child: Text('Result')),
                                ),
                              ),
                            ],
                            rows: _tableData.asMap().entries.map((entry) {
                              int index = entry.key;
                              Map<String, dynamic> data = entry.value;
                              return DataRow(cells: [
                                DataCell(
                                  Center(
                                    child: Checkbox(
                                      value: selectedRows.contains(index),
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            selectedRows.add(index);
                                          } else {
                                            selectedRows.remove(index);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text((index + 1).toString()),
                                  ),
                                ),
                                DataCell(
                                  TextField(
                                    textAlign: TextAlign.center,
                                    focusNode: _ensureFocusNode(index),
                                    onChanged: (value) {
                                      setState(() {
                                        data['content'] = value;
                                        if (value.isNotEmpty) {
                                          String result = _validateContent(value, index);
                                          data['result'] = result;
                                          print('Content: $value, Result: $result');
                                        } else {
                                          data['result'] = '';
                                        }
                                        _updateCounts();
                                      });
                                    },
                                    onSubmitted: (value) {
                                      if (!_isQtyPerBoxReached) {
                                        setState(() {
                                          _tableData.add({
                                            'content': '',
                                            'result': '',
                                          });
                                          _focusNodes.add(FocusNode());
                                          Future.delayed(const Duration(milliseconds: 100), () {
                                            _focusNodes.last.requestFocus();
                                          });
                                          _updateCounts();
                                        });
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Center(
                                    child: Text(
                                      data['result'] ?? '',
                                      style: TextStyle(
                                        color: data['result'] == 'Good' ? Colors.green : 
                                               data['result'] == 'No Good' ? Colors.red : 
                                               Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),

                      // Add Delete Selected button
                      if (selectedRows.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
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
                                onPressed: () {
                                  setState(() {
                                    // Sort indices in descending order to avoid index shifting issues
                                    final sortedIndices = selectedRows.toList()..sort((a, b) => b.compareTo(a));
                                    for (final index in sortedIndices) {
                                      if (index < _focusNodes.length) {
                                        _focusNodes[index].dispose();
                                        _focusNodes.removeAt(index);
                                      }
                                      _tableData.removeAt(index);
                                    }
                                    selectedRows.clear();
                                    
                                    // Add a new row if table is empty
                                    if (_tableData.isEmpty) {
                                      _tableData.add({
                                        'content': '',
                                        'result': '',
                                      });
                                      _focusNodes.add(FocusNode());
                                    }
                                    
                                    _updateCounts();
                                  });
                                },
                                child: const Text('Delete Selected'),
                              ),
                            ],
                          ),
                        ),

                      // Add Done button when QTY is reached
                      if (_isQtyPerBoxReached)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _showOptionsDialog,
                                child: const Text('Done'),
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
        ],
      ),
    );
  }
}
