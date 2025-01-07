import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Add variables for historical data
  List<Map<String, dynamic>> _historicalData = [];
  int _currentPage = 1;
  static const int _pageSize = 10;
  int _totalItems = 0;
  bool _isLoadingHistory = false;

  // Add these variables for sorting and searching
  String _searchQuery = '';
  String _sortColumn = 'created_at';
  bool _sortAscending = false;

  int _historicalGoodCount = 0; // New variable for historical good count
  int _historicalNoGoodCount = 0; // New variable for historical no good count

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
        final convertedChar = subLotNum == 10
            ? '0'
            : String.fromCharCode('A'.codeUnitAt(0) + (subLotNum - 11));
        return '$mainPart$convertedChar'; // Combine without dash
      }
    } catch (e) {
      print('Error converting sub-lot number: $e');
    }

    // Return original format without dash if conversion fails or not needed
    return parts.join('');
  }

  // Add new method to fetch total counts
  Future<void> _updateTotalGoodNoGoodCounts() async {
    try {
      final counts = await DatabaseHelper().getTotalGoodNoGoodCounts(itemName);
      setState(() {
        _historicalGoodCount = counts['goodCount'] ?? 0;
        _historicalNoGoodCount = counts['noGoodCount'] ?? 0;
        // Update the display counters
        int currentGoodCount = 0;
        int currentNoGoodCount = 0;

        // Count current session
        for (var data in _tableData) {
          if (data['content']?.isNotEmpty == true) {
            if (data['result'] == 'Good') {
              currentGoodCount++;
            } else if (data['result'] == 'No Good') {
              currentNoGoodCount++;
            }
          }
        }

        // Update the display with total counts
        goodCountController.text =
            (_historicalGoodCount + currentGoodCount).toString();
        noGoodCountController.text =
            (_historicalNoGoodCount + currentNoGoodCount).toString();
      });
    } catch (e) {
      print('Error updating total Good/No Good counts: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    _fetchLabelContent(itemName);
    _checkSubLotRules();
    _loadHistoricalData();

    // Check total inspection quantity at load time
    _updateTotalInspectionQty().then((_) {
      int currentInspectionQty =
          int.tryParse(inspectionQtyController.text) ?? 0;
      int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;

      if (currentInspectionQty >= totalTargetQty) {
        setState(() {
          _isTotalQtyReached = true;
        });
        // Show the dialog after a brief delay to ensure the widget is fully built
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!_hasShownQtyReachedDialog) {
            _hasShownQtyReachedDialog = true;
            _showTotalQtyReachedDialog();
          }
        });
      }
    });

    // If resuming from unfinished item, restore the table data
    if (widget.resumeData != null) {
      // Restore table data from resumeData
      final List<dynamic> savedTableData = widget.resumeData!['tableData'];
      _tableData.clear();
      _tableData.addAll(savedTableData.map((item) => {
            'content': item['content'] ?? '',
            'result': item['result'] ?? '',
          }));

      // Create focus nodes for each row
      _focusNodes.clear();
      for (int i = 0; i < _tableData.length; i++) {
        _focusNodes.add(FocusNode());
      }

      // Add an empty row if needed and if total QTY not reached
      if (!_isQtyPerBoxReached && !_isTotalQtyReached) {
        _tableData.add({
          'content': '',
          'result': '',
        });
        _focusNodes.add(FocusNode());
      }
    } else {
      // Initialize with a single empty row for new scan if total QTY not reached
      _tableData.clear();
      _focusNodes.clear();
      if (!_isTotalQtyReached) {
        _tableData.add({
          'content': '',
          'result': '',
        });
        _focusNodes.add(FocusNode());
      }
    }

    // Set the total quantity
    if (widget.resumeData != null) {
      totalQtyController.text =
          widget.resumeData!['quantity'] ?? totalQty.toString();
    } else {
      totalQtyController.text = totalQty.toString();
    }

    // Update counts for restored data and get historical counts
    _updateTotalGoodNoGoodCounts();
    if (widget.resumeData != null) {
      _updateCounts();
    }

    // Set focus to the first content field after the widget is built if not total QTY reached
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty && !_isTotalQtyReached) {
        _focusNodes[0].requestFocus();
      }
    });
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
              (code['hasSubLot'] == 1 || code['hasSubLot'] == true));
        });
      }
    } catch (e) {
      print('Error checking sub-lot rules: $e');
    }
  }

  Future<void> _loadHistoricalData() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final data = await DatabaseHelper().getHistoricalScans(
        itemName,
        page: _currentPage,
        pageSize: _pageSize,
      );

      final total = await DatabaseHelper().getHistoricalScansCount(itemName);

      setState(() {
        _historicalData = data;
        _totalItems = total;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Error loading historical data: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  void _loadNextPage() {
    if (_currentPage * _pageSize < _totalItems) {
      setState(() {
        _currentPage++;
      });
      _loadHistoricalData();
    }
  }

  void _loadPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
      });
      _loadHistoricalData();
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

  void _validateContent(String value, int index) async {
    final expectedContent =
        '${_labelContent ?? ''}_${_convertSubLotNumber(lotNumber)}';

    if (value == expectedContent) {
      setState(() {
        _tableData[index]['result'] = 'Good';
      });

      // Save the individual scan content
      await DatabaseHelper().insertScanContent(
        operatorScanId,
        value,
        'Good',
      );
    } else {
      setState(() {
        _tableData[index]['result'] = 'No Good';
      });

      // Save the failed scan
      await DatabaseHelper().insertScanContent(
        operatorScanId,
        value,
        'No Good',
      );
    }

    _updateCounts();
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

  Future<void> _updateTotalInspectionQty() async {
    try {
      // Get total historical scans for this item
      final historicalTotal = await DatabaseHelper().getTotalScansForItem(itemName);

      // Calculate current scans (only count rows with content)
      int currentGoodCount = 0;
      int currentNoGoodCount = 0;

      for (var data in _tableData) {
        if (data['content']?.isNotEmpty == true) {  // Only count rows with content
          if (data['result'] == 'Good') {
            currentGoodCount++;
          } else if (data['result'] == 'No Good') {
            currentNoGoodCount++;
          }
        }
      }

      // Update inspection quantity controller with total
      setState(() {
        inspectionQtyController.text =
            (historicalTotal + currentGoodCount + currentNoGoodCount).toString();
      });
    } catch (e) {
      print('Error updating total inspection quantity: $e');
    }
  }

  void _updateCounts() {
    int goodCount = 0;
    int noGoodCount = 0;
    int populatedRowCount = 0;

    // Only count rows that have content
    for (var data in _tableData) {
      if (data['content']?.isNotEmpty == true) {  // Check if content exists and is not empty
        populatedRowCount++;
        if (data['result'] == 'Good') {
          goodCount++;
        } else if (data['result'] == 'No Good') {
          noGoodCount++;
        }
      }
    }

    setState(() {
      // Update QTY per box
      qtyPerBoxController.text = populatedRowCount.toString();

      // Check if we've reached the QTY per box
      String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
      int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;

      // Check if total QTY has been reached
      int currentInspectionQty = int.tryParse(inspectionQtyController.text) ?? 0;
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

    // Update total inspection quantity after counts are updated
    _updateTotalInspectionQty();
    // Update Good/No Good counts
    _updateTotalGoodNoGoodCounts();
  }

  void _showQtyReachedDialog() {
    // First, remove focus from any text field
    FocusManager.instance.primaryFocus?.unfocus();

    // Small delay to ensure unfocus completes before showing dialog
    Future.delayed(const Duration(milliseconds: 100), () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: kBorderRadiusSmallAll,
            ),
            title: const Text('Information'),
            content: const Text('QTY per box has been reached'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
              FocusScope(
                autofocus: true,
                child: ElevatedButton(
                  autofocus: true,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
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
              ),
            ],
          );
        },
      );
    });
  }

  void _showTotalQtyReachedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: kBorderRadiusSmallAll,
          ),
          title: const Text('Information'),
          content: const Text('TOTAL QTY has been reached'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
            FocusScope(
              autofocus: true,
              child: ElevatedButton(
                autofocus: true,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleReviewSummary();
                },
                child: const Text('Review Finished Item'),
              ),
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

  List<DataRow> _buildTableRows() {
    return _tableData.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> data = entry.value;

      // Create a TextEditingController for this row
      final contentController = TextEditingController(text: data['content']);

      return DataRow(
        cells: [
          DataCell(
            Checkbox(
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
          DataCell(Text((index + 1).toString())),
          DataCell(
            TextField(
              focusNode: _ensureFocusNode(index),
              controller: contentController,
              autofocus: index == 0,
              enabled: !_isTotalQtyReached,
              onChanged: (value) {
                setState(() {
                  data['content'] = value;
                });
              },
              onSubmitted: (value) {
                if (value.isNotEmpty && !_isTotalQtyReached) {
                  setState(() {
                    _validateContent(value, index);
                    _updateCounts();

                    // Always move to next row or create new row on Enter
                    if (index == _tableData.length - 1 && !_isTotalQtyReached) {
                      _addRow();
                      // Focus the new row after a short delay
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _ensureFocusNode(_tableData.length - 1).requestFocus();
                      });
                    } else if (index < _tableData.length - 1) {
                      // Move focus to next row if it exists
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _ensureFocusNode(index + 1).requestFocus();
                      });
                    }
                  });
                }
              },
              onEditingComplete: () {
                String value = data['content'] ?? '';
                if (value.isNotEmpty && !_isTotalQtyReached) {
                  setState(() {
                    _validateContent(value, index);
                    _updateCounts();
                  });
                }
              },
              onTapOutside: (event) {
                String value = data['content'] ?? '';
                if (value.isNotEmpty && !_isTotalQtyReached) {
                  setState(() {
                    _validateContent(value, index);
                    _updateCounts();
                  });
                }
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: kBorderRadiusNoneAll,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: kBorderRadiusNoneAll,
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: kBorderRadiusNoneAll,
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),
          DataCell(
            Text(
              data['result'] ?? '',
              style: TextStyle(
                color: data['result'] == 'Good'
                    ? Colors.green
                    : data['result'] == 'No Good'
                        ? Colors.red
                        : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  // Add this method to handle sorting
  void _sort<T>(
      String column, Comparable<T> Function(Map<String, dynamic>) getField) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }

      // Create a mutable copy of the data before sorting
      final mutableData = List<Map<String, dynamic>>.from(_historicalData);
      mutableData.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return _sortAscending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
      _historicalData = mutableData;
    });
  }

  // Add this method to filter data based on search query
  List<Map<String, dynamic>> _getFilteredData() {
    if (_searchQuery.isEmpty) return _historicalData;

    // Create a mutable copy for filtering
    return List<Map<String, dynamic>>.from(_historicalData).where((item) {
      final searchLower = _searchQuery.toLowerCase();
      final itemName = (item['itemName'] ?? '').toLowerCase();
      final poNo = (item['poNo'] ?? '').toLowerCase();
      final content = (item['content'] ?? '').toLowerCase();
      final result = (item['result'] ?? '').toLowerCase();
      final date = DateTime.parse(item['created_at']).toString().toLowerCase();

      return itemName.contains(searchLower) ||
          poNo.contains(searchLower) ||
          content.contains(searchLower) ||
          result.contains(searchLower) ||
          date.contains(searchLower);
    }).toList();
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

          // Back Button and Title
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Back'),
                ),
                const Expanded(child: SizedBox()),
                const SelectableText(
                  'Scan Item',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const Expanded(child: SizedBox()),
                Row(
                  children: [
                    const SelectableText(
                      'Good: ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: kBorderRadiusSmallAll,
                      ),
                      child: SelectableText(
                        goodCountController.text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                    const SelectableText(
                      'No Good: ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: kBorderRadiusSmallAll,
                      ),
                      child: SelectableText(
                        noGoodCountController.text,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth;
                  return Container(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Item Details Container
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: kBorderRadiusSmallAll,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Section (40% width)
                              SizedBox(
                                width: maxWidth * 0.4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectableText('Item Name: $itemName',
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 12),
                                    SelectableText('P.O No: $poNo',
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 12),
                                    SelectableText('Lot Number: $lotNumber',
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 24),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SelectableText(
                                          'Content:',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(height: 8),
                                        SelectableText(
                                          '${_labelContent ?? ''}${_labelContent != null ? '_' : ''}${_convertSubLotNumber(lotNumber)}',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Right Section (50% width)
                              SizedBox(
                                width: maxWidth * 0.5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: maxWidth * 0.15,
                                          child: const SelectableText(
                                              'Total QTY',
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                        SizedBox(
                                          width: maxWidth * 0.35,
                                          child: TextField(
                                            controller: totalQtyController,
                                            enabled: false,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: maxWidth * 0.15,
                                          child: SelectableText(
                                              'QTY per box (${qtyPerBox})',
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                        SizedBox(
                                          width: maxWidth * 0.35,
                                          child: TextField(
                                            controller: qtyPerBoxController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: maxWidth * 0.15,
                                          child: const SelectableText(
                                              'Inspection QTY',
                                              style: TextStyle(fontSize: 16)),
                                        ),
                                        SizedBox(
                                          width: maxWidth * 0.35,
                                          child: TextField(
                                            controller: inspectionQtyController,
                                            decoration: const InputDecoration(
                                              border: OutlineInputBorder(),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                            ),
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
                        const SizedBox(height: 24),

                        // Scan Table
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: kBorderRadiusSmallAll,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: maxWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowColor: MaterialStateProperty.all(
                                    Colors.grey.shade100),
                                columns: const [
                                  DataColumn(label: Text('')),
                                  DataColumn(label: Text('No.')),
                                  DataColumn(label: Text('Content')),
                                  DataColumn(label: Text('Result')),
                                ],
                                rows: _buildTableRows(),
                              ),
                            ),
                          ),
                        ),

                        // Action Buttons Row
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                    ),
                                  ),
                                  onPressed: _handleReviewSummary,
                                  child: const Text('Review Summary'),
                                )
                              else
                                // Show Add Row button
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                    ),
                                  ),
                                  onPressed: _addRow,
                                  child: const Text('Add Row'),
                                ),
                              const SizedBox(width: 16),
                              // Delete Selected button
                              if (selectedRows.isNotEmpty)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: kBorderRadiusSmallAll,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      final sortedIndices = selectedRows
                                          .toList()
                                        ..sort((a, b) => b.compareTo(a));
                                      for (final index in sortedIndices) {
                                        if (index < _focusNodes.length) {
                                          _focusNodes[index].dispose();
                                          _focusNodes.removeAt(index);
                                        }
                                        _tableData.removeAt(index);
                                      }
                                      selectedRows.clear();

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
                              if (_isQtyPerBoxReached) ...[
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: kBorderRadiusSmallAll,
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
                            ],
                          ),
                        ),

                        // Historical Data Section
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: kBorderRadiusSmallAll,
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Previous Scans',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Add search field
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search in previous scans...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: kBorderRadiusSmallAll,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_isLoadingHistory)
                                const Center(child: CircularProgressIndicator())
                              else if (_historicalData.isEmpty)
                                const Text('No historical data available')
                              else
                                Column(
                                  children: [
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: maxWidth,
                                        ),
                                        child: DataTable(
                                          columnSpacing: 24,
                                          headingRowColor:
                                              MaterialStateProperty.all(
                                                  Colors.grey.shade100),
                                          sortColumnIndex: [
                                            'created_at',
                                            'itemName',
                                            'poNo',
                                            'content',
                                            'result'
                                          ].indexOf(_sortColumn),
                                          sortAscending: _sortAscending,
                                          columns: [
                                            DataColumn(
                                              label:
                                                  const SelectableText('Date'),
                                              onSort: (_, __) => _sort<String>(
                                                'created_at',
                                                (item) => item['created_at'],
                                              ),
                                            ),
                                            DataColumn(
                                              label: const SelectableText(
                                                  'Item Name'),
                                              onSort: (_, __) => _sort<String>(
                                                'itemName',
                                                (item) =>
                                                    item['itemName'] ?? '',
                                              ),
                                            ),
                                            DataColumn(
                                              label:
                                                  const SelectableText('PO No'),
                                              onSort: (_, __) => _sort<String>(
                                                'poNo',
                                                (item) => item['poNo'] ?? '',
                                              ),
                                            ),
                                            DataColumn(
                                              label: const SelectableText(
                                                  'Content'),
                                              onSort: (_, __) => _sort<String>(
                                                'content',
                                                (item) => item['content'] ?? '',
                                              ),
                                            ),
                                            DataColumn(
                                              label: const SelectableText(
                                                  'Result'),
                                              onSort: (_, __) => _sort<String>(
                                                'result',
                                                (item) => item['result'] ?? '',
                                              ),
                                            ),
                                          ],
                                          rows: _getFilteredData().map((item) {
                                            final DateTime createdAt =
                                                DateTime.parse(
                                                    item['created_at']);
                                            final formattedDate =
                                                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}:${createdAt.second.toString().padLeft(2, '0')}';

                                            return DataRow(
                                              cells: [
                                                DataCell(SelectableText(
                                                    formattedDate)),
                                                DataCell(SelectableText(
                                                    item['itemName'] ?? '')),
                                                DataCell(SelectableText(
                                                    item['poNo'] ?? '')),
                                                DataCell(SelectableText(
                                                    item['content'] ?? '')),
                                                DataCell(
                                                  SelectableText(
                                                    item['result'] ?? '',
                                                    style: TextStyle(
                                                      color: item['result'] ==
                                                              'Good'
                                                          ? Colors.green
                                                          : Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Updated pagination footer
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft:
                                              kBorderRadiusSmallAll.bottomLeft,
                                          bottomRight:
                                              kBorderRadiusSmallAll.bottomRight,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Summary info
                                          Text(
                                            'Showing ${(_currentPage - 1) * _pageSize + 1} to ${_currentPage * _pageSize > _totalItems ? _totalItems : _currentPage * _pageSize} of $_totalItems entries',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF666666),
                                            ),
                                          ),
                                          // Pagination controls
                                          Row(
                                            children: [
                                              OutlinedButton(
                                                onPressed: _currentPage > 1
                                                    ? _loadPreviousPage
                                                    : null,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.deepPurple,
                                                  side: const BorderSide(
                                                      color: Colors.deepPurple),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.arrow_back,
                                                        size: 16),
                                                    SizedBox(width: 4),
                                                    Text('Previous'),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      kBorderRadiusSmallAll,
                                                  border: Border.all(
                                                      color:
                                                          Colors.grey.shade300),
                                                ),
                                                child: Text(
                                                  'Page $_currentPage of ${(_totalItems / _pageSize).ceil()}',
                                                  style: const TextStyle(
                                                      fontSize: 14),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              OutlinedButton(
                                                onPressed:
                                                    _currentPage * _pageSize <
                                                            _totalItems
                                                        ? _loadNextPage
                                                        : null,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.deepPurple,
                                                  side: const BorderSide(
                                                      color: Colors.deepPurple),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Text('Next'),
                                                    SizedBox(width: 4),
                                                    Icon(Icons.arrow_forward,
                                                        size: 16),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
