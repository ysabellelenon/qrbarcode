import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import '../constants.dart'; // Import constants for styling
import '../database_helper.dart'; // Import the DatabaseHelper
import 'article_label.dart'; // Add this import
import 'emergency_stop.dart'; // Add this import
import 'finished_item.dart'; // Add this import
import '../widgets/previous_scans_table.dart';
import 'dart:async'; // Add this import for Timer

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
  final List<TextEditingController> _contentControllers = [];
  Timer? _debounceTimer;
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

  String _scanBuffer = ''; // Add this line to store scanner input

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

  final String _sessionId = DateTime.now().millisecondsSinceEpoch.toString();

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
      // Get historical counts
      final historicalCounts = await DatabaseHelper().getTotalGoodNoGoodCounts(
        itemName,
        excludeSessionId: _sessionId,
      );
      
      // Get current session counts
      final currentCounts = await DatabaseHelper().getCurrentSessionCounts(
        itemName,
        _sessionId,
      );
      
      setState(() {
        goodCountController.text = 
          ((historicalCounts['goodCount'] ?? 0) + (currentCounts['goodCount'] ?? 0)).toString();
        noGoodCountController.text = 
          ((historicalCounts['noGoodCount'] ?? 0) + (currentCounts['noGoodCount'] ?? 0)).toString();
        
        // Update inspection QTY with group count
        inspectionQtyController.text = 
          ((historicalCounts['goodCount'] ?? 0) + (historicalCounts['noGoodCount'] ?? 0) + 
           (currentCounts['groupCount'] ?? 0)).toString();
      });
    } catch (e) {
      print('Error updating total Good/No Good counts: $e');
    }
  }

  Future<void> _updateTotalInspectionQty() async {
    try {
      // Get historical completed groups for this item
      final historicalGroups = await DatabaseHelper().getTotalScansForItem(itemName);
      
      // Count current groups (not individual scans)
      Set<dynamic> uniqueGroups = _tableData
        .where((item) => item['result']?.isNotEmpty == true)
        .map((item) => item['groupNumber'] ?? item)
        .toSet();
      final currentGroups = uniqueGroups.length;
      
      print('Updating Inspection QTY:');
      print('Historical groups: $historicalGroups');
      print('Current groups: $currentGroups');

      setState(() {
        // Total inspection QTY is historical + current groups
        inspectionQtyController.text = 
          ((historicalGroups ?? 0) + currentGroups).toString();
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
      _contentControllers.add(TextEditingController());

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
    try {
      // Count only Good results for QTY per box
      int currentGoodGroups = 0;
      
      if (_itemCategory == 'Non-Counting') {
        // Group scans by session
        Map<String, List<Map<String, dynamic>>> sessionGroups = {};
        
        for (var data in _tableData.where((item) => 
          item['result']?.isNotEmpty == true)) {
          String sessionId = data['sessionId'] ?? _sessionId;
          if (!sessionGroups.containsKey(sessionId)) {
            sessionGroups[sessionId] = [];
          }
          sessionGroups[sessionId]!.add(data);
        }
        
        // Count completed groups with all Good results
        sessionGroups.forEach((sessionId, sessionData) {
          int codesInGroup = sessionData.first['codesInGroup'] ?? 1;
          
          // Process each group
          for (int i = 0; i < sessionData.length; i += codesInGroup) {
            // Get all scans in this group
            var groupScans = sessionData.skip(i).take(codesInGroup).toList();
            
            // Only count if group is complete and all scans are Good
            if (groupScans.length == codesInGroup && 
                groupScans.every((scan) => scan['result'] == 'Good')) {
              currentGoodGroups++;
            }
          }
        });
      } else {
        // For counting items, count individual Good scans
        currentGoodGroups = _tableData
          .where((item) => item['result'] == 'Good')
          .length;
      }
      
      setState(() {
        // Update QTY per box with only Good groups
        qtyPerBoxController.text = currentGoodGroups.toString();

        // Check if QTY per box is reached
        String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
        int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;
        _isQtyPerBoxReached = targetQty > 0 && currentGoodGroups >= targetQty;

        // Check if total QTY has been reached
        int totalInspectionQty = int.tryParse(inspectionQtyController.text) ?? 0;
        int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;
        _isTotalQtyReached = totalInspectionQty >= totalTargetQty;
      });

      // Show dialogs if needed
      if (_isQtyPerBoxReached && !_isTotalQtyReached && !_hasShownQtyReachedDialog) {
        _hasShownQtyReachedDialog = true;
        _showQtyReachedDialog();
      }

      if (_isTotalQtyReached && !_hasShownQtyReachedDialog) {
        _hasShownQtyReachedDialog = true;
        _showTotalQtyReachedDialog();
      }
    } catch (e) {
      print('Error in _checkAndUpdateQtyStatus: $e');
    }
  }

  void _showQtyReachedDialog() {
    // First, remove focus from any text field
    FocusManager.instance.primaryFocus?.unfocus();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by clicking outside
      builder: (context) => WillPopScope(
        // Also prevent dismissing with back button
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Information'),
          content: const Text('QTY per box has been reached'),
          actions: [
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
                      hideBackButton: true,
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
    // Group data by session first
    Map<String, List<Map<String, dynamic>>> sessionGroups = {};
    
    for (var data in _tableData.where((item) => 
      item['content']?.isNotEmpty == true)) {  // Only include rows with content
      String sessionId = data['sessionId'] ?? _sessionId;
      if (!sessionGroups.containsKey(sessionId)) {
        sessionGroups[sessionId] = [];
      }
      sessionGroups[sessionId]!.add(data);
    }

    List<DataRow> allRows = [];
    int lastGroupNumber = 0;
    
    // Process each session's data separately
    sessionGroups.forEach((sessionId, sessionData) {
      // Sort by timestamp if available
      sessionData.sort((a, b) => 
        (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
      
      // Process rows for this session
      for (int i = 0; i < sessionData.length; i++) {
        var data = sessionData[i];
        int codesInGroup = data['codesInGroup'] ?? 1;
        
        // Show group number only for first scan in each group within this session
        bool isFirstInGroup = i % codesInGroup == 0;
        int groupNumber = (i ~/ codesInGroup) + 1;
        
        if (isFirstInGroup) {
          lastGroupNumber = groupNumber;
        }
        
        allRows.add(DataRow(
          cells: [
            DataCell(Text(isFirstInGroup ? groupNumber.toString() : '')),
            DataCell(
              Text(data['content'] ?? ''),  // Show completed scans as text
            ),
            DataCell(
              Text(
                data['result'] ?? '',
                style: TextStyle(
                  color: data['result'] == 'Good' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ));
      }
    });

    // Add single empty row for next scan
    allRows.add(DataRow(
      cells: [
        DataCell(Text((lastGroupNumber + 1).toString())),
        DataCell(
          TextField(
            controller: TextEditingController(),
            focusNode: _ensureFocusNode(allRows.length),
            enabled: !_isTotalQtyReached,
            autofocus: true,  // Automatically focus the input field
            onChanged: (value) {
              _scanBuffer = value;
            },
            onSubmitted: (value) {
              if (value.isNotEmpty && !_isTotalQtyReached) {
                Future.delayed(const Duration(milliseconds: 50), () {
                  if (mounted) {
                    final completeValue = _scanBuffer;
                    _validateContent(completeValue, allRows.length - 1);
                    _scanBuffer = '';
                  }
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
        const DataCell(Text('')),
      ],
    ));

    return allRows;
  }

  /// Validates the scanned content and updates the result.
  Future<void> _validateContent(String value, int index) async {
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
        int serialCount =
            int.tryParse(countingCode['serialCount']?.toString() ?? '0') ?? 0;

        // Get the base content (everything before the serial number)
        String baseDisplayContent =
            _displayContent.substring(0, _displayContent.length - serialCount);
        String scannedBaseContent =
            value.substring(0, value.length - serialCount);

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
              if (_tableData.indexOf(row) == index ||
                  row['content']?.isEmpty == true) return false;
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

        // Calculate group information for current session only
        int previousScans = _tableData
            .where((row) =>
                row['result']?.isNotEmpty == true &&
                row['sessionId'] == _sessionId &&
                _tableData.indexOf(row) < index)
            .length;

        // Calculate current group number (1-based)
        int currentGroup = (previousScans ~/ noOfCodes) + 1;

        setState(() {
          // Show row number if:
          // 1. This is the first scan in a group, OR
          // 2. Previous group is complete and this is a new scan
          bool isFirstInGroup = previousScans % noOfCodes == 0;
          bool previousGroupComplete =
              previousScans > 0 && previousScans % noOfCodes == 0;

          _tableData[index]['showRowNumber'] = isFirstInGroup;
          _tableData[index]['rowNumber'] = currentGroup;
          _tableData[index]['sessionId'] = _sessionId;
        });
      }
    }

    // Save to database and update UI
    try {
      if (_itemCategory == 'Non-Counting') {
        final items = await DatabaseHelper().getItems();
        final matchingItem = items.firstWhere(
          (item) => item['itemCode'] == itemName,
          orElse: () => {},
        );
        int noOfCodes = int.parse(matchingItem['codeCount'] ?? '1');
        
        // Calculate groups only within the current session
        final currentSessionScans = _tableData
            .where((row) => 
              row['result']?.isNotEmpty == true && 
              row['sessionId'] == _sessionId)
            .toList();
        
        // Calculate current group based only on scans from this session
        int previousCompletedGroups = currentSessionScans.length ~/ noOfCodes;
        int currentGroup = previousCompletedGroups + 1;

        // Get position within current group (0-based)
        int positionInGroup = currentSessionScans.length % noOfCodes;

        // Save to database with session and code count information
        await DatabaseHelper().insertScanContent(
          operatorScanId,
          value,
          result,
          groupNumber: currentGroup,
          groupPosition: positionInGroup + 1,
          codesInGroup: noOfCodes,
          sessionId: _sessionId,
        );

        setState(() {
          _tableData[index] = {
            'content': value,
            'result': result,
            'isLocked': true,
            'sessionId': _sessionId,
            'codesInGroup': noOfCodes,
            'groupNumber': currentGroup,
            'groupPosition': positionInGroup + 1,
            'timestamp': DateTime.now().toString(),
          };
        });
      } else {
        // For counting items, no group information needed
        await DatabaseHelper().insertScanContent(
          operatorScanId,
          value,
          result,
          sessionId: _sessionId,
        );

        setState(() {
          _tableData[index] = {
            'content': value,
            'result': result,
            'isLocked': true,
            'sessionId': _sessionId,
            'timestamp': DateTime.now().toString(),
          };
        });
      }

      // Update totals after the state is updated
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
            content: const Text(
                'A "No Good" result has been recorded. Please review the issue.'),
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
    _debounceTimer?.cancel();
    // Clean up focus nodes and controllers
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _contentControllers) {
      controller.dispose();
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
            bool hasSubLotRules = countingCode['hasSubLot'] == 1 ||
                countingCode['hasSubLot'] == true;

            // Get serial count for Counting items
            int serialCount =
                int.tryParse(countingCode['serialCount']?.toString() ?? '0') ??
                    0;
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
                  convertedSubLot =
                      String.fromCharCode('A'.codeUnitAt(0) + (subLotNum - 11));
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
                    print("Emergency button pressed - checking if it's a valid mouse click");
                    // Only handle direct mouse clicks, ignore keyboard events
                    if (RendererBinding.instance.mouseTracker.mouseIsConnected) {
                      print("Mouse is connected - proceeding with emergency stop");
                      // Add a small delay to prevent accidental triggers
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          // Calculate progress info
                          final int currentQty = int.tryParse(qtyPerBoxController.text) ?? 0;
                          final int targetQty = int.tryParse(widget.scanData?['qtyPerBox'] ?? '0') ?? 0;
                          final bool isIncomplete = currentQty < targetQty;
                          
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
                              isIncomplete: isIncomplete, // Add this flag
                              targetQty: targetQty,       // Add target quantity info
                            ),
                          );
                        }
                      });
                    } else {
                      print("Ignoring emergency button press - not from mouse");
                    }
                  },
                  // Make button completely unfocusable
                  focusNode: NeverFocusableNode(),
                  autofocus: false,
                  onFocusChange: (_) => false,
                  child: const Text('Emergency'),
                ),
              ],
            ),
          ),

          // Fixed Header Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                const SizedBox(height: 20),

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
                      Expanded(
                        flex: 4,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                SizedBox(
                                  width: 160,
                                  child: SelectableText('Total QTY',
                                      style: TextStyle(fontSize: 16)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: totalQtyController,
                                    enabled: false,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
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
                                  width: 160,
                                  child: SelectableText(
                                    'QTY per box (${widget.scanData?['qtyPerBox'] ?? ''})',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: qtyPerBoxController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
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
                                  width: 160,
                                  child: SelectableText('Inspection QTY',
                                      style: TextStyle(fontSize: 16)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: inspectionQtyController,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
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
              ],
            ),
          ),

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
                              else if (!_isQtyPerBoxReached &&
                                  !_isTotalQtyReached)
                                // Only show Add Row button if neither QTY limit is reached
                                const SizedBox(width: 16),
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
                                          hideBackButton: true,
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

  // Add this helper method
  TextEditingController _getOrCreateController(int index) {
    while (_contentControllers.length <= index) {
      _contentControllers.add(TextEditingController());
    }
    _contentControllers[index].text = _tableData[index]['content'] ?? '';
    return _contentControllers[index];
  }

  // Add this helper method to get the current group count
  int _getCurrentGroupCount() {
    if (_itemCategory == 'Non-Counting') {
      // Group scans by session first
      Map<String, List<Map<String, dynamic>>> sessionGroups = {};
      
      for (var data in _tableData.where((item) => 
        item['result']?.isNotEmpty == true)) {
        String sessionId = data['sessionId'] ?? _sessionId;
        if (!sessionGroups.containsKey(sessionId)) {
          sessionGroups[sessionId] = [];
        }
        sessionGroups[sessionId]!.add(data);
      }

      int totalGroups = 0;
      
      // Count completed groups for each session separately
      sessionGroups.forEach((sessionId, sessionData) {
        // Sort data by timestamp
        sessionData.sort((a, b) => 
          (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));
        
        // Get the codes in group for this session
        int codesInGroup = sessionData.first['codesInGroup'] ?? 1;
        
        // Count complete groups in this session
        int completeGroups = sessionData.length ~/ codesInGroup;
        totalGroups += completeGroups;
      });

      return totalGroups;
    } else {
      // For counting items, count individual good scans
      return _tableData
        .where((item) => item['result'] == 'Good')
        .length;
    }
  }
}

// Add this class at the top of the file or in a separate utilities file
class NeverFocusableNode extends FocusNode {
  @override
  bool get canRequestFocus => false;
  
  @override
  bool consumeKeyboardToken() {
    return false;
  }
}
