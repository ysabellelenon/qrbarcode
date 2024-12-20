import 'package:flutter/material.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import the DatabaseHelper
import 'article_label.dart'; // Add this import
import 'emergency_stop.dart'; // Add this import
import 'finished_item.dart'; // Add this import

class ScanItem extends StatefulWidget {
  final Map<String, dynamic>? resumeData;
  final Map<String, dynamic>? scanData;

  const ScanItem({
    Key? key,
    this.resumeData,
    this.scanData,
  }) : super(key: key);

  @override
  State<ScanItem> createState() => _ScanItemState();
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
  final Set<String> _usedContents =
      {}; // To track used contents for "Counting" category
  final List<FocusNode> _focusNodes = [];
  final Set<int> selectedRows = {};
  bool _isQtyPerBoxReached = false;
  int currentRowNumber = 1;
  bool _hasShownQtyReachedDialog = false;
  bool _isTotalQtyReached = false; // Add this flag
  bool _hasSubLotRules = false; // Add this variable

  String get itemName =>
      widget.scanData?['itemName'] ?? widget.resumeData?['itemName'] ?? '';
  String get poNo =>
      widget.scanData?['poNo'] ?? widget.resumeData?['poNo'] ?? '';
  String get lotNumber =>
      widget.scanData?['lotNumber'] ?? widget.resumeData?['lotNumber'] ?? '';
  String get content =>
      widget.scanData?['content'] ?? widget.resumeData?['content'] ?? '';
  String get qtyPerBox =>
      widget.resumeData?['qtyPerBox'] ?? widget.scanData?['qtyPerBox'] ?? '';
  int get operatorScanId =>
      widget.resumeData?['operatorScanId'] ??
      widget.scanData?['operatorScanId'] ??
      0;
  int get totalQty =>
      widget.resumeData?['totalQty'] ?? widget.scanData?['totalQty'] ?? 0;

  // Add this method to convert sub-lot numbers
  String _convertSubLotNumber(String lotNumber) {
    if (!_hasSubLotRules || lotNumber.isEmpty) return lotNumber;

    // Split the lot number at the dash
    final parts = lotNumber.split('-');
    if (parts.length != 2) return lotNumber;

    final mainPart = parts[0];
    final subLotPart = parts[1];

    // Try to parse the sub-lot number
    try {
      final subLotNum = int.parse(subLotPart);
      // Only convert if it's between 10 and 20
      if (subLotNum >= 10 && subLotNum <= 20) {
        // Convert number to letter (10=0, 11=A, 12=B, etc.)
        final convertedChar = subLotNum == 10 ? '0' : 
                            String.fromCharCode('A'.codeUnitAt(0) + (subLotNum - 11));
        return '$mainPart$convertedChar'; // Combine without dash
      }
    } catch (e) {
      print('Error converting sub-lot number: $e');
    }

    // Return original format without dash if conversion fails or not needed
    return parts.join('');
  }

  @override
  void initState() {
    super.initState();
    _fetchLabelContent(itemName);
    _checkSubLotRules();
    
    // If resuming from unfinished item, restore the table data
    if (widget.resumeData != null) {
      // Restore table data from resumeData
      final List<dynamic> savedTableData = widget.resumeData!['tableData'];
      _tableData.clear(); // Clear default empty row
      _tableData.addAll(savedTableData.map((item) => {
            'content': item['content'] ?? '',
            'result': item['result'] ?? '',
          }));

      // Create focus nodes for each row
      for (int i = 0; i < _tableData.length; i++) {
        _focusNodes.add(FocusNode());
      }

      // Add an empty row if needed
      if (!_isQtyPerBoxReached) {
        _tableData.add({
          'content': '',
          'result': '',
        });
        _focusNodes.add(FocusNode());
      }

      // Update counts
      _updateCounts();
    } else {
      // Normal initialization for new scan
      _tableData.add({
        'content': '',
        'result': '',
      });
      _focusNodes.add(FocusNode());
    }

    // Set the total quantity
    if (widget.resumeData != null) {
      // Use the quantity from unfinished item
      totalQtyController.text =
          widget.resumeData!['quantity'] ?? totalQty.toString();
    } else {
      // Use the quantity from operator login or scan data
      totalQtyController.text = totalQty.toString();
    }

    // Initialize with current counts
    goodCountController.text = '0';
    noGoodCountController.text = '0';

    // Update counts to reflect restored data
    if (widget.resumeData != null) {
      _updateCounts();
    }
  }

  Future<void> _checkSubLotRules() async {
    try {
      final items = await DatabaseHelper().getItems();
      final matchingItem = items.firstWhere(
        (item) => item['itemCode'] == itemName,
        orElse: () => {},
      );

      if (matchingItem.isNotEmpty) {
        final codes = matchingItem['codes'] as List;
        setState(() {
          _hasSubLotRules = codes.any((code) => 
            code['category'] == 'Counting' && 
            (code['hasSubLot'] == 1 || code['hasSubLot'] == true)
          );
        });
      }
    } catch (e) {
      print('Error checking sub-lot rules: $e');
    }
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

  void _validateContent(String content, int rowIndex) {
    if (_itemCategory == null || _labelContent == null) {
      print('Category or label content is null');
      return;
    }

    // Construct the full static content by combining label content and lot number
    String staticContent = '${_labelContent}_${_convertSubLotNumber(lotNumber)}';

    print('Validating content: $content');
    print('Category: $_itemCategory');
    print('Static Content: $staticContent');
    print('Row Index: $rowIndex');

    String result = '';

    if (_itemCategory == 'Non-Counting') {
      // For Non-Counting items:
      // Content MUST match the static content exactly to be Good
      result = content == staticContent ? 'Good' : 'No Good';
      print('Non-Counting validation - Content matches static: ${content == staticContent}');
    } else if (_itemCategory == 'Counting') {
      // For Counting items:
      // 1. Content must NOT match the static content
      if (content == staticContent) {
        result = 'No Good';
        print('Counting validation - Content matches static (No Good)');
      } else {
        // 2. Content must be unique (not used in any other row)
        bool isDuplicate = false;
        for (int i = 0; i < _tableData.length; i++) {
          if (i != rowIndex && // Skip current row
              _tableData[i]['content']?.isNotEmpty == true && // Check non-empty contents
              _tableData[i]['content'] == content) { // Check if content matches
            isDuplicate = true;
            print('Found duplicate content in row $i');
            break;
          }
        }
        
        if (isDuplicate) {
          result = 'No Good';
          print('Counting validation - Duplicate content found (No Good)');
        } else {
          // 3. Additional check: Content must not match any converted lot number format
          String unconvertedContent = content;
          String convertedContent = _convertSubLotNumber(content);
          
          if (unconvertedContent == staticContent || convertedContent == staticContent) {
            result = 'No Good';
            print('Counting validation - Content matches static in either format (No Good)');
          } else {
            result = 'Good';
            print('Counting validation - Content is unique and doesn\'t match static (Good)');
          }
        }
      }
    }

    setState(() {
      _tableData[rowIndex]['result'] = result;
      _updateCounts();

      // Add new row if this is the last row and QTY not reached
      if (rowIndex == _tableData.length - 1 && !_isQtyPerBoxReached) {
        String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
        int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;

        if (targetQty > 0 && _tableData.length < targetQty) {
          _tableData.add({
            'content': '',
            'result': '',
          });
          _focusNodes.add(FocusNode());

          // Focus on the new row after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            _focusNodes.last.requestFocus();
          });
        }
      }
    });
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
    int populatedRowCount = 0;

    for (var data in _tableData) {
      if (data['content']?.isNotEmpty == true) {
        populatedRowCount++;
        if (data['result'] == 'Good') {
          goodCount++;
        } else if (data['result'] == 'No Good') {
          noGoodCount++;
        }
      }
    }

    setState(() {
      goodCountController.text = goodCount.toString();
      noGoodCountController.text = noGoodCount.toString();
      inspectionQtyController.text = (goodCount + noGoodCount).toString();
      qtyPerBoxController.text = populatedRowCount.toString();

      // Check if we've reached the QTY per box
      String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
      int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;

      // Check if total QTY has been reached
      int currentInspectionQty = goodCount + noGoodCount;
      int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;

      // Update the total QTY reached flag
      _isTotalQtyReached = currentInspectionQty >= totalTargetQty;

      bool wasQtyReached = widget.resumeData != null &&
          widget.resumeData!.containsKey('isQtyReached') &&
          widget.resumeData!['isQtyReached'] == true;

      if (_isTotalQtyReached) {
        // Show Total QTY reached dialog
        if (!_hasShownQtyReachedDialog) {
          _hasShownQtyReachedDialog = true;
          _showTotalQtyReachedDialog();
        }
      } else if (targetQty > 0 && populatedRowCount >= targetQty) {
        _isQtyPerBoxReached = true;
        if (!wasQtyReached && !_hasShownQtyReachedDialog) {
          _hasShownQtyReachedDialog = true;
          _showQtyReachedDialog();
        }
      } else {
        _isQtyPerBoxReached = false;
        _hasShownQtyReachedDialog = false;
      }
    });
  }

  void _showQtyReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap OK to dismiss
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

  void _showTotalQtyReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap OK to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Information'),
          content: const Text('TOTAL QTY has been reached'),
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

  void addNewTableRow(String content) {
    setState(() {
      _tableData.add({'content': content, 'result': 'Good'});
      currentRowNumber++;
    });
  }

  // Add this method to handle Review Summary button press
  void _handleReviewSummary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FinishedItem(
          itemName: itemName,
          lotNumber: lotNumber,
          content: _labelContent ?? content,
          poNo: poNo,
          quantity: qtyPerBoxController.text,
          tableData: _tableData
              .where((item) => item['content']?.isNotEmpty == true)
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        ),
      ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    print('Debug - itemName: $itemName');
                    print('Debug - lotNumber: $lotNumber');
                    print('Debug - content: $content');
                    print('Debug - poNo: $poNo');

                    showDialog(
                      context: context,
                      builder: (context) => EmergencyStop(
                        itemName: itemName,
                        lotNumber: lotNumber,
                        content: _labelContent ?? content,
                        poNo: poNo,
                        quantity: qtyPerBoxController.text,
                        tableData: _tableData
                            .where(
                                (item) => item['content']?.isNotEmpty == true)
                            .map((item) => Map<String, dynamic>.from(item))
                            .toList(),
                        username: 'operator',
                      ),
                    );
                  },
                  child: const Text('Emergency'),
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
                  constraints: const BoxConstraints(
                      maxWidth: 1200), // Increased from 900
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
                                  Text('Item Name: $itemName',
                                      style: const TextStyle(fontSize: 16)),
                                  Text('P.O No: $poNo',
                                      style: const TextStyle(fontSize: 16)),
                                  Text('Lot Number: $lotNumber',
                                      style: const TextStyle(fontSize: 16)),
                                  const SizedBox(height: 32),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Content:',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${_labelContent ?? ''}${_labelContent != null ? '_' : ''}${_convertSubLotNumber(lotNumber)}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
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
                                        child: Text('Total QTY',
                                            style: TextStyle(fontSize: 16)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: totalQtyController,
                                          decoration: const InputDecoration(
                                              border: OutlineInputBorder()),
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
                                          'QTY per box ($qtyPerBox)',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: qtyPerBoxController,
                                          decoration: const InputDecoration(
                                              border: OutlineInputBorder()),
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
                                        child: Text('Inspection QTY',
                                            style: TextStyle(fontSize: 16)),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: TextField(
                                          controller: inspectionQtyController,
                                          decoration: const InputDecoration(
                                              border: OutlineInputBorder()),
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
                              const SizedBox(
                                  width: 16), // Reduced spacing between inputs
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate dynamic widths based on container width
                              final double checkboxWidth =
                                  constraints.maxWidth * 0.05; // 5%
                              final double numberWidth =
                                  constraints.maxWidth * 0.05; // 5%
                              final double contentWidth =
                                  constraints.maxWidth * 0.35; // 35%
                              final double resultWidth =
                                  constraints.maxWidth * 0.25; // 25%

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  dividerThickness: 1,
                                  border: TableBorder(
                                    verticalInside: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                    horizontalInside: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                    left: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                    right: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                    top: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                    bottom: BorderSide(
                                        width: 1, color: Colors.grey.shade300),
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: SizedBox(
                                        width: checkboxWidth,
                                        child: const Center(
                                            child: Text('')), // For checkbox
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: numberWidth,
                                        child: const Center(child: Text('No.')),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: contentWidth,
                                        child: const Center(
                                            child: Text('Content')),
                                      ),
                                    ),
                                    DataColumn(
                                      label: SizedBox(
                                        width: resultWidth,
                                        child:
                                            const Center(child: Text('Result')),
                                      ),
                                    ),
                                  ],
                                  rows: _tableData.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    Map<String, dynamic> data = entry.value;
                                    return DataRow(cells: [
                                      DataCell(
                                        SizedBox(
                                          width: checkboxWidth,
                                          child: Center(
                                            child: Checkbox(
                                              value:
                                                  selectedRows.contains(index),
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
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: numberWidth,
                                          child: Center(
                                            child: Text((index + 1).toString()),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: contentWidth,
                                          child: TextField(
                                            textAlign: TextAlign.center,
                                            focusNode: _ensureFocusNode(index),
                                            controller: TextEditingController(
                                                text: data['content']),
                                            onChanged: (value) {
                                              setState(() {
                                                data['content'] = value;
                                                if (value.isNotEmpty) {
                                                  _validateContent(
                                                      value, index);
                                                } else {
                                                  data['result'] = '';
                                                }
                                                _updateCounts();
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      horizontal: 8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: resultWidth,
                                          child: Center(
                                            child: Text(
                                              data['result'] ?? '',
                                              style: TextStyle(
                                                color: data['result'] == 'Good'
                                                    ? Colors.green
                                                    : data['result'] ==
                                                            'No Good'
                                                        ? Colors.red
                                                        : Colors.black,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Add Delete Selected and Add Row buttons
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 10,
                          bottom: 30,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_isTotalQtyReached)
                              // Show Review Summary button
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
                                onPressed: _handleReviewSummary,
                                child: const Text('Review Summary'),
                              )
                            else
                              // Show Add Row button
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _addRow,
                                child: const Text('Add Row'),
                              ),

                            // Delete Selected button
                            if (selectedRows.isNotEmpty)
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
                                    final sortedIndices = selectedRows.toList()
                                      ..sort((a, b) => b.compareTo(a));
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

                      // Add Scan New Article Label button when QTY is reached
                      if (_isQtyPerBoxReached)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 10),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
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
                                    onPressed: () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (context) => ArticleLabel(
                                            itemName: itemName,
                                            poNo: poNo,
                                            operatorScanId: operatorScanId,
                                            totalQty: totalQty,
                                            resumeData: widget.resumeData,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Scan New Article Label'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
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
