import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import the DatabaseHelper
import 'article_label.dart'; // Add this import
import 'emergency_stop.dart'; // Add this import
import 'finished_item.dart'; // Add this import
import '../widgets/previous_scans_table.dart';

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
  String? _labelContent;
  String? _itemCategory;
  String _displayContent = '';
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
        goodCountController.text = (counts['goodCount'] ?? 0).toString();
        noGoodCountController.text = (counts['noGoodCount'] ?? 0).toString();
      });
    } catch (e) {
      print('Error updating total Good/No Good counts: $e');
    }
  }

  Future<void> _updateTotalInspectionQty() async {
    try {
      // Get total historical scans for this item
      final historicalTotal =
          await DatabaseHelper().getTotalScansForItem(itemName);

      setState(() {
        inspectionQtyController.text = historicalTotal.toString();
      });
    } catch (e) {
      print('Error updating total inspection quantity: $e');
    }
  }

  void _addRow() {
    // Don't add new rows if QTY per box is reached
    if (_isQtyPerBoxReached) {
      _showQtyReachedDialog();
      return;
    }

    setState(() {
      _tableData.add({
        'content': '',
        'result': '',
        'isLocked': false,
      });
      _focusNodes.add(FocusNode());

      // Focus the new row immediately
      Future.delayed(const Duration(milliseconds: 100), () {
        _focusNodes.last.requestFocus();
      });
    });
  }

  FocusNode _ensureFocusNode(int index) {
    // Add focus nodes if needed
    while (_focusNodes.length <= index) {
      _focusNodes.add(FocusNode());
    }
    return _focusNodes[index];
  }

  @override
  void initState() {
    super.initState();

    _fetchLabelContent(itemName);
    _checkSubLotRules();

    // Set the total quantity first
    totalQtyController.text = totalQty.toString();

    // Initialize counts and check QTY status
    _initializeCountsAndStatus();

    // If resuming from unfinished item, restore the table data
    if (widget.resumeData != null) {
      // Restore table data from resumeData
      final List<dynamic> savedTableData = widget.resumeData!['tableData'];
      _tableData.clear();
      _tableData.addAll(savedTableData.map((item) => {
            'content': item['content'] ?? '',
            'result': item['result'] ?? '',
            'isLocked': true, // Lock restored rows
          }));

      // Create focus nodes for each row
      _focusNodes.clear();
      for (int i = 0; i < _tableData.length; i++) {
        _focusNodes.add(FocusNode());
      }
    }

    // Set focus to the first content field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty && !_isTotalQtyReached) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  // New method to initialize counts and check status
  Future<void> _initializeCountsAndStatus() async {
    await _updateTotalInspectionQty();
    await _updateTotalGoodNoGoodCounts();

    // Check if total QTY is already reached
    int currentInspectionQty = int.tryParse(inspectionQtyController.text) ?? 0;
    int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;

    setState(() {
      _isTotalQtyReached = currentInspectionQty >= totalTargetQty;
    });

    // Only add an empty row if total QTY is not reached
    if (!_isTotalQtyReached && _tableData.isEmpty) {
      _tableData.add({
        'content': '',
        'result': '',
        'isLocked': false,
      });
      _focusNodes.add(FocusNode());
    }

    // Check and update QTY status after initialization
    _checkAndUpdateQtyStatus();
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

  void _checkAndUpdateQtyStatus() async {
    if (_itemCategory == 'Non-Counting') {
      final items = await DatabaseHelper().getItems();
      final matchingItem = items.firstWhere(
        (item) => item['itemCode'] == itemName,
        orElse: () => {},
      );
      int noOfCodes = int.parse(matchingItem['codeCount'] ?? '1');
      
      // Count complete groups and their results
      int goodGroups = 0;
      int noGoodGroups = 0;
      
      // Initialize groups map with empty lists
      Map<int, List<Map<String, dynamic>>> groups = {};
      
      // Group scans by their position in sequence
      for (int i = 0; i < _tableData.length; i++) {
        if (_tableData[i]['result']?.isNotEmpty == true) {
          int currentGroup = i ~/ noOfCodes;
          // Initialize the list for this group if it doesn't exist
          groups.putIfAbsent(currentGroup, () => <Map<String, dynamic>>[]);
          // Now we can safely add to the list
          groups[currentGroup]!.add(_tableData[i]);
        }
      }
      
      // Evaluate each complete group
      groups.forEach((groupIndex, scans) {
        if (scans.length == noOfCodes) {
          // A group is "Good" only if all scans in the group are "Good"
          bool isGroupGood = scans.every((scan) => scan['result'] == 'Good');
          if (isGroupGood) {
            goodGroups++;
          } else {
            noGoodGroups++;
          }
        }
      });
      
      setState(() {
        // Update the good/no good counts based on complete groups
        goodCountController.text = goodGroups.toString();
        noGoodCountController.text = noGoodGroups.toString();
        
        // Update inspection quantity based on complete groups
        int totalCompleteGroups = goodGroups + noGoodGroups;
        inspectionQtyController.text = totalCompleteGroups.toString();
        
        // Update QTY per box based on complete groups
        qtyPerBoxController.text = totalCompleteGroups.toString();
        
        // Check if total quantity is reached
        int totalQty = int.tryParse(totalQtyController.text) ?? 0;
        _isTotalQtyReached = totalCompleteGroups >= totalQty;
        
        // Check if QTY per box is reached
        int targetQtyPerBox = int.tryParse(qtyPerBox) ?? 0;
        _isQtyPerBoxReached = totalCompleteGroups > 0 && totalCompleteGroups == targetQtyPerBox;

        // Remove the empty row if QTY is reached
        if ((_isQtyPerBoxReached || _isTotalQtyReached) && _tableData.isNotEmpty) {
          // Remove the last row if it's empty
          if (_tableData.last['content']?.isEmpty == true) {
            _tableData.removeLast();
            if (_focusNodes.isNotEmpty) {
              _focusNodes.last.dispose();
              _focusNodes.removeLast();
            }
          }
        }
      });
      
      // Show QTY per box dialog if reached and total QTY not reached
      if (_isQtyPerBoxReached && !_isTotalQtyReached && !_hasShownQtyReachedDialog) {
        _hasShownQtyReachedDialog = true;
        _showQtyReachedDialog();
      }
      
      // Show total QTY dialog if reached
      if (_isTotalQtyReached && !_hasShownQtyReachedDialog) {
        _hasShownQtyReachedDialog = true;
        _showTotalQtyReachedDialog();
      }
    } else {
      // For Counting items - keep existing logic
      int populatedRowCount = _tableData
          .where((data) => data['content']?.isNotEmpty == true)
          .length;

      setState(() {
        // Update QTY per box
        qtyPerBoxController.text = populatedRowCount.toString();

        // Check if we've reached the QTY per box
        String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
        int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;

        // Check if total QTY has been reached
        int currentInspectionQty = int.tryParse(inspectionQtyController.text) ?? 0;
        int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;

        _isTotalQtyReached = currentInspectionQty >= totalTargetQty;

        // Check if QTY per box is reached
        if (targetQty > 0 && populatedRowCount >= targetQty && !_isTotalQtyReached) {
          _isQtyPerBoxReached = true;
        }

        // Remove the empty row if QTY is reached
        if ((_isQtyPerBoxReached || _isTotalQtyReached) && _tableData.isNotEmpty) {
          // Remove the last row if it's empty
          if (_tableData.last['content']?.isEmpty == true) {
            _tableData.removeLast();
            if (_focusNodes.isNotEmpty) {
              _focusNodes.last.dispose();
              _focusNodes.removeLast();
            }
          }
        }
      });
      
      // Show total QTY dialog if reached
      if (_isTotalQtyReached && !_hasShownQtyReachedDialog) {
        _hasShownQtyReachedDialog = true;
        _showTotalQtyReachedDialog();
      }
    }
  }

  void _showQtyReachedDialog() {
    // First, remove focus from any text field
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by clicking outside
      builder: (context) => WillPopScope( // Also prevent dismissing with back button
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Information'),
          content: const Text('QTY per box has been reached'),
          actions: [
            // Only show Scan New Article Label button
            TextButton(
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
      ),
    );
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
    if (_itemCategory == 'Non-Counting') {
      return _tableData.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> data = entry.value;
        
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
            DataCell(
              Text(data['showRowNumber'] == true ? 
                  data['rowNumber'].toString() : '')
            ),
            DataCell(
              TextField(
                focusNode: _ensureFocusNode(index),
                controller: TextEditingController(text: data['content']),
                autofocus: index == 0,
                enabled: !_isTotalQtyReached && !(data['isLocked'] == true),
                onChanged: (value) {
                  setState(() {
                    data['content'] = value;
                  });
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty && !_isTotalQtyReached && !(data['isLocked'] == true)) {
                    _validateContent(value, index);
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
                  filled: data['isLocked'] == true,
                  fillColor: data['isLocked'] == true ? Colors.grey.shade100 : null,
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
                  fontSize: data['result'] == 'No Good' ? 20 : 16, // Increased font size for "No Good"
                ),
              ),
            ),
          ],
        );
      }).toList();
    } else {
      // Original implementation for Counting items
      return _tableData.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> data = entry.value;
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
                enabled: !_isTotalQtyReached &&
                    !(data['isLocked'] == true), // Disable if locked
                onChanged: (value) {
                  setState(() {
                    data['content'] = value;
                  });
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty &&
                      !_isTotalQtyReached &&
                      !(data['isLocked'] == true)) {
                    _validateContent(value, index);
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
                  filled: data['isLocked'] ==
                      true, // Add background color for locked fields
                  fillColor:
                      data['isLocked'] == true ? Colors.grey.shade100 : null,
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
                  fontSize: data['result'] == 'No Good' ? 20 : 16, // Increased font size for "No Good"
                ),
              ),
            ),
          ],
        );
      }).toList();
    }
  }

  /// Validates the scanned content and updates the result.
  void _validateContent(String value, int index) async {
    print('\n====== Starting Content Validation ======');
    print('Row Index: $index');
    print('Label Content from Database: $_labelContent');
    print('Scanned Value: $value');
    print('Item Category: $_itemCategory');

    // If QTY per box is reached, don't allow new scans
    if (_isQtyPerBoxReached) {
      _showQtyReachedDialog();
      return;
    }

    // If this row already has a result, don't validate again
    if (_tableData[index]['result']?.isNotEmpty == true) {
      print('Row already validated - skipping');
      return;
    }

    final items = await DatabaseHelper().getItems();
    final matchingItem = items.firstWhere(
      (item) => item['itemCode'] == itemName,
      orElse: () => <String, dynamic>{},
    );

    String result = 'No Good'; // Default to No Good
    
    if (matchingItem.isNotEmpty) {
      final codes = matchingItem['codes'] as List;
      final countingCode = codes.firstWhere(
        (code) => code['category'] == 'Counting',
        orElse: () => <String, dynamic>{},
      );
      
      bool isCountingItem = countingCode.isNotEmpty;
      
      if (isCountingItem) {
        // Get the serial count for validation
        int serialCount = int.tryParse(countingCode['serialCount']?.toString() ?? '0') ?? 0;
        
        // Get the base content (everything before the serial number)
        String baseDisplayContent = _displayContent.substring(0, _displayContent.length - serialCount);
        String scannedBaseContent = value.substring(0, value.length - serialCount);
        
        print('Base Display Content: "$baseDisplayContent"');
        print('Scanned Base Content: "$scannedBaseContent"');
        
        // Exact comparison of base content
        if (baseDisplayContent != scannedBaseContent) {
          print('Base content mismatch');
          result = 'No Good';
        } else {
          // Validate the serial part
          String serialPart = value.substring(value.length - serialCount);
          if (serialPart.length == serialCount) {
            // Check for duplicates
            bool isDuplicate = _tableData.any((row) {
              if (_tableData.indexOf(row) == index || row['content']?.isEmpty == true) return false;
              return row['content'] == value;
            });
            
            result = isDuplicate ? 'No Good' : 'Good';
          } else {
            print('Serial part length mismatch');
            result = 'No Good';
          }
        }
      } else {
        // For non-counting items
        int noOfCodes = int.parse(matchingItem['codeCount'] ?? '1');
        
        if (value != _displayContent) {
          result = 'No Good';
        } else {
          result = 'Good';
        }

        // Calculate group information immediately
        int previousScans = _tableData
            .where((row) => 
                row['result']?.isNotEmpty == true && 
                _tableData.indexOf(row) < index)
            .length;
        
        // Calculate current group number (1-based)
        int currentGroup = (previousScans ~/ noOfCodes) + 1;
        
        setState(() {
          // Show row number if:
          // 1. This is the first scan in a group, OR
          // 2. Previous group is complete and this is a new scan
          bool isFirstInGroup = previousScans % noOfCodes == 0;
          bool previousGroupComplete = previousScans > 0 && previousScans % noOfCodes == 0;
          
          _tableData[index]['showRowNumber'] = isFirstInGroup;
          _tableData[index]['rowNumber'] = currentGroup;
        });
      }
    }

    // Save to database and update UI
    try {
      await DatabaseHelper().insertScanContent(
        operatorScanId,
        value,
        result,
      );

      setState(() {
        _tableData[index]['result'] = result;
        _tableData[index]['isLocked'] = true;
      });

      await _updateTotalInspectionQty();
      await _updateTotalGoodNoGoodCounts();
      _checkAndUpdateQtyStatus();

      if (!_isTotalQtyReached) {
        _addRow();
      }

      // If the result is "No Good", show an alert dialog
      if (result == 'No Good') {
        _showNoGoodAlert();
      }
    } catch (e) {
      print('Error saving scan content: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving scan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Displays an alert dialog when a "No Good" result is recorded.
  void _showNoGoodAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (event) {
            if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
              Navigator.of(context).pop(); // Close dialog on Enter
            }
          },
          child: AlertDialog(
            title: const Text('Alert'),
            content: const Text('A "No Good" result has been recorded. Please review the issue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                autofocus: true, // Auto focus the OK button
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
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
          final codes = matchingItem['codes'] as List;
          final countingCode = codes.firstWhere(
            (code) => code['category'] == 'Counting',
            orElse: () => <String, dynamic>{},
          );
          
          final nonCountingCode = codes.firstWhere(
            (code) => code['category'] == 'Non-Counting',
            orElse: () => <String, dynamic>{},
          );
          
          if (countingCode.isNotEmpty) {
            _labelContent = countingCode['content'];
            _itemCategory = 'Counting';
            
            // Check if sub-lot rules are enabled for this item
            bool hasSubLotRules = countingCode['hasSubLot'] == 1 || countingCode['hasSubLot'] == true;
            
            // Get serial count for Counting items
            int serialCount = int.tryParse(countingCode['serialCount']?.toString() ?? '0') ?? 0;
            print('Serial Count from masterlist: $serialCount');
            
            // Format lot number with sub-lot rules if enabled
            String formattedLotNumber = '';
            if (lotNumber.contains('-')) {
              final parts = lotNumber.split('-');
              final mainPart = parts[0];
              final subLotPart = parts[1];
              
              if (hasSubLotRules) {
                // Convert sub-lot number according to rules if between 10-20
                int subLotNum = int.tryParse(subLotPart) ?? 0;
                String convertedSubLot;
                
                if (subLotNum == 10) {
                  convertedSubLot = '0';
                } else if (subLotNum >= 11 && subLotNum <= 20) {
                  // Convert to letters A-J (11=A, 12=B, etc.)
                  convertedSubLot = String.fromCharCode('A'.codeUnitAt(0) + (subLotNum - 11));
                } else {
                  // For numbers outside 10-20, just use the number
                  convertedSubLot = subLotNum.toString();
                }
                
                formattedLotNumber = '$mainPart$convertedSubLot';
                print('Sub-lot conversion: $subLotPart -> $convertedSubLot');
              } else {
                // No sub-lot rules, just remove leading zeros
                int subLotNum = int.tryParse(subLotPart) ?? 0;
                formattedLotNumber = '$mainPart$subLotNum';
              }
            } else {
              formattedLotNumber = lotNumber;
            }
            
            // Add asterisks for Counting items
            String asterisks = '*' * serialCount;
            _displayContent = '${_labelContent}$formattedLotNumber$asterisks';
            
            print('Base Content: ${_labelContent}');
            print('Formatted Lot Number: $formattedLotNumber');
            print('Asterisks: $asterisks');
            print('Final Display Content: $_displayContent');
          } else if (nonCountingCode.isNotEmpty) {
            _labelContent = nonCountingCode['content'];
            _itemCategory = 'Non-Counting';
            _displayContent = '${_labelContent}$lotNumber';
            
            print('Base Content: ${_labelContent}');
            print('Original Lot Number: $lotNumber');
            print('Final Display Content: $_displayContent');
          }
        } else {
          _labelContent = 'No content available';
          _itemCategory = null;
          _displayContent = 'No content available';
        }
      });
    } else {
      setState(() {
        _labelContent = 'Item not found';
        _itemCategory = null;
        _displayContent = 'Item not found';
      });
    }
  }

  void _resetInspectionQty() {
    setState(() {
      inspectionQtyController.text = '0';
      goodCountController.text = '0';
      noGoodCountController.text = '0';
    });
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
                    // Only respond to direct button clicks
                    if (FocusScope.of(context).hasFocus) return;
                    
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => WillPopScope(
                        onWillPop: () async => false,
                        child: AlertDialog(
                          title: const Text('Emergency Stop'),
                          content: const Text('Are you sure you want to stop the operation?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => EmergencyStop(
                                    itemName: itemName,
                                    lotNumber: lotNumber,
                                    content: _labelContent ?? content,
                                    poNo: poNo,
                                    quantity: qtyPerBoxController.text,
                                    tableData: _tableData
                                        .where((item) => item['content']?.isNotEmpty == true)
                                        .map((item) => Map<String, dynamic>.from(item))
                                        .toList(),
                                    username: 'operator',
                                  ),
                                );
                              },
                              child: const Text('Confirm Stop'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  // Prevent keyboard focus
                  focusNode: AlwaysDisabledFocusNode(),
                  child: const Text('Emergency'),
                ),
              ],
            ),
          ),

          // Back Button Removed
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // OutlinedButton for 'Back' has been removed
                // const OutlinedButton(
                //   onPressed: () {
                //     Navigator.of(context).pop();
                //   },
                //   child: const Text('Back'),
                // ),
                const SelectableText(
                  'Scan Item',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
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
                                          _displayContent,
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
                              else if (!_isQtyPerBoxReached && !_isTotalQtyReached)
                                // Only show Add Row button if neither QTY limit is reached
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
                                          'isLocked': false,
                                        });
                                        _focusNodes.add(FocusNode());
                                      }

                                      _checkAndUpdateQtyStatus();
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
                        PreviousScansTable(
                          itemName: itemName,
                          showClearButton: true,
                          onDataCleared: () {
                            _resetInspectionQty();
                            _updateTotalInspectionQty();
                            _updateTotalGoodNoGoodCounts();
                            _checkAndUpdateQtyStatus();
                          },
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

// Add this class at the top of the file or in a separate utilities file
class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
