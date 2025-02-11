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
  bool _preserveHistory = false; // Add this flag

  // Add variables for historical data
  int _historicalGoodCount = 0; // New variable for historical good count
  int _historicalNoGoodCount = 0; // New variable for historical no good count

  String _scanBuffer = ''; // Add this line to store scanner input

  // Add new field to store pending scans
  final List<Map<String, dynamic>> _pendingScans = [];

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
  Future<void> _updateGroupCounts() async {
    try {
      print('\n=== Updating Group Counts ===');
      final db = await DatabaseHelper();

      // Get all completed group counts from database
      final counts = await db.getGroupedScanCounts(itemName, poNo);

      // Get codes per group from item configuration
      final items = await db.getItems();
      final matchingItem = items.firstWhere(
        (item) => item['itemCode'] == itemName,
        orElse: () => {},
      );
      int codesPerGroup = int.parse(matchingItem['codeCount'] ?? '1');
      print('Codes per group: $codesPerGroup');

      // Count current session groups that aren't saved to database yet
      final currentSessionScans = _tableData
          .where((item) =>
              item['result']?.isNotEmpty == true &&
              !item['isLocked'] == true) // Only count unlocked (unsaved) scans
          .toList();
      int currentSessionGoodGroups = 0;
      int currentSessionNoGoodGroups = 0;
      int currentSessionCompletedGroups = 0;

      // Process current session scans in groups
      for (int i = 0; i < currentSessionScans.length; i += codesPerGroup) {
        // Only process complete groups
        if (i + codesPerGroup <= currentSessionScans.length) {
          currentSessionCompletedGroups++;
          final groupScans = currentSessionScans.sublist(i, i + codesPerGroup);
          bool isGroupGood =
              groupScans.every((scan) => scan['result'] == 'Good');

          if (isGroupGood) {
            currentSessionGoodGroups++;
            print(
                'Current Session Good Group - Index: ${(i ~/ codesPerGroup) + 1}');
          } else {
            currentSessionNoGoodGroups++;
            print(
                'Current Session No Good Group - Index: ${(i ~/ codesPerGroup) + 1}');
          }
        }
      }

      print('Database - Inspection QTY: ${counts['inspectionQty']}');
      print('Database - Good Groups: ${counts['goodCount']}');
      print('Database - No Good Groups: ${counts['noGoodCount']}');
      print('Pending - Completed Groups: $currentSessionCompletedGroups');
      print('Pending - Good Groups: $currentSessionGoodGroups');
      print('Pending - No Good Groups: $currentSessionNoGoodGroups');

      // Update all counts
      setState(() {
        inspectionQtyController.text =
            (counts['inspectionQty']! + currentSessionCompletedGroups)
                .toString();
        goodCountController.text =
            (counts['goodCount']! + currentSessionGoodGroups).toString();
        noGoodCountController.text =
            (counts['noGoodCount']! + currentSessionNoGoodGroups).toString();
      });

      print(
          'Total Inspection QTY: ${counts['inspectionQty']! + currentSessionCompletedGroups}');
      print(
          'Total Good Groups: ${counts['goodCount']! + currentSessionGoodGroups}');
      print(
          'Total No Good Groups: ${counts['noGoodCount']! + currentSessionNoGoodGroups}');

      // Check and update QTY status after updating counts
      _checkAndUpdateQtyStatus();
    } catch (e) {
      print('Error updating group counts: $e');
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
    print('\n=== Initializing ScanItem ===');
    _preserveHistory = widget.scanData?['preserveHistory'] == true;
    print('Preserve History: $_preserveHistory');

    _fetchLabelContent(itemName);
    _checkSubLotRules();

    // Set the total quantity first
    totalQtyController.text = totalQty.toString();

    // Initialize counts and check QTY status
    _initializeCountsAndStatus();

    // If resuming from unfinished item, restore the table data
    if (widget.resumeData != null) {
      print('Restoring from resume data');
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

    // Add state restoration
    if (!_preserveHistory) {
      _restorePreviousState();
    }
  }

  // New method to initialize counts and check status
  Future<void> _initializeCountsAndStatus() async {
    await _updateGroupCounts();

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
      print('\n=== Checking and Updating QTY Status ===');

      // Get codes per group from item configuration
      final items = await DatabaseHelper().getItems();
      final matchingItem = items.firstWhere(
        (item) => item['itemCode'] == itemName,
        orElse: () => {},
      );
      int codesPerGroup = int.parse(matchingItem['codeCount'] ?? '1');
      print('Codes per group: $codesPerGroup');

      // Group the scans by session and group number for current session only
      Map<int, List<Map<String, dynamic>>> currentSessionGroups = {};

      for (var scan in _tableData.where((item) =>
          item['result']?.isNotEmpty == true &&
          item['sessionId'] == _sessionId)) {
        int groupNum = scan['groupNumber'] ?? 1;
        currentSessionGroups[groupNum] = currentSessionGroups[groupNum] ?? [];
        currentSessionGroups[groupNum]!.add(scan);
      }

      // Count completed good groups in current session
      int completedGoodGroups = 0;
      currentSessionGroups.forEach((groupNum, scans) {
        if (scans.length == codesPerGroup) {
          // Only count completed groups
          bool isGroupGood = scans.every((scan) => scan['result'] == 'Good');
          if (isGroupGood) {
            completedGoodGroups++;
          }
        }
      });

      print('Completed good groups in current session: $completedGoodGroups');

      setState(() {
        // Update QTY per box with completed good groups count
        qtyPerBoxController.text = completedGoodGroups.toString();
        print('Updated QTY per box: $completedGoodGroups');

        // Check if QTY per box is reached
        String qtyPerBoxStr = widget.scanData?['qtyPerBox'] ?? '';
        int targetQty = int.tryParse(qtyPerBoxStr) ?? 0;
        _isQtyPerBoxReached = targetQty > 0 && completedGoodGroups >= targetQty;
        print('QTY per box reached: $_isQtyPerBoxReached (Target: $targetQty)');

        // Check if total QTY has been reached
        int totalInspectionQty =
            int.tryParse(inspectionQtyController.text) ?? 0;
        int totalTargetQty = int.tryParse(totalQtyController.text) ?? 0;
        _isTotalQtyReached = totalInspectionQty >= totalTargetQty;
        print(
            'Total QTY reached: $_isTotalQtyReached (Total: $totalInspectionQty, Target: $totalTargetQty)');
      });

      // Show dialogs if needed
      if (_isQtyPerBoxReached &&
          !_isTotalQtyReached &&
          !_hasShownQtyReachedDialog) {
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
          quantity: totalQtyController.text,
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

    for (var data
        in _tableData.where((item) => item['content']?.isNotEmpty == true)) {
      // Only include rows with content
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
      sessionData.sort(
          (a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

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
              Text(data['content'] ?? ''), // Show completed scans as text
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
            autofocus: true, // Automatically focus the input field
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
    int codeCount = int.parse(matchingItem['codeCount'] ?? '1');

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

        // Check if sub-lot rules are enabled for this item
        bool hasSubLotRules =
            countingCode['hasSubLot'] == 1 || countingCode['hasSubLot'] == true;

        // For validation, we need to compare against the original lot number format
        String expectedBaseContent;
        if (hasSubLotRules && lotNumber.contains('-')) {
          // Use the original lot number format for validation
          String baseContent = _labelContent ?? '';
          expectedBaseContent = '$baseContent$lotNumber';

          // Remove the dash if present in the expected content
          expectedBaseContent = expectedBaseContent.replaceAll('-', '');

          print('Expected Base Content: "$expectedBaseContent"');
          print('Scanned Base Content: "$scannedBaseContent"');

          // Compare the scanned content against the original format
          if (scannedBaseContent.startsWith(baseContent)) {
            // Extract and compare the lot number portion
            String scannedLotPortion =
                scannedBaseContent.substring(baseContent.length);
            String expectedLotPortion =
                expectedBaseContent.substring(baseContent.length);

            if (scannedLotPortion == expectedLotPortion) {
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
              }
            }
          }
        } else {
          // Regular validation without sub-lot rules
          if (baseDisplayContent == scannedBaseContent) {
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
            }
          }
        }
      } else {
        // For non-counting items, exact content matching
        if (value == _displayContent) {
          result = 'Good';
        }
      }
    }

    // Calculate group information for current session
    final currentSessionScans = _tableData
        .where((row) =>
            row['result']?.isNotEmpty == true && row['sessionId'] == _sessionId)
        .toList();

    // Calculate current group based only on scans from this session
    int previousCompletedGroups = currentSessionScans.length ~/ codeCount;
    int currentGroup = previousCompletedGroups + 1;

    // Get position within current group (0-based)
    int positionInGroup = currentSessionScans.length % codeCount;

    // Create scan data
    final scanData = {
      'content': value,
      'result': result,
      'isLocked': true,
      'sessionId': _sessionId,
      'codesInGroup': codeCount,
      'groupNumber': currentGroup,
      'groupPosition': positionInGroup + 1,
      'timestamp': DateTime.now().toString(),
    };

    // Add to pending scans
    _pendingScans.add(scanData);

    // Update UI immediately to show the scan
    setState(() {
      _tableData[index] = scanData;
    });

    // Check if we have a complete group
    if (_pendingScans.length == codeCount) {
      print('\n=== Processing Complete Group ===');
      print('Pending scans count: ${_pendingScans.length}');
      print('Codes per group: $codeCount');

      try {
        // Save all scans in the group to database
        for (var scan in _pendingScans) {
          await DatabaseHelper().insertScanContent(
            operatorScanId,
            scan['content'],
            scan['result'],
            groupNumber: scan['groupNumber'],
            groupPosition: scan['groupPosition'],
            codesInGroup: scan['codesInGroup'],
            sessionId: scan['sessionId'],
          );
        }

        // Clear pending scans after successful save
        _pendingScans.clear();

        // Update totals after the group is saved
        await _updateGroupCounts();
        _checkAndUpdateQtyStatus();

        if (!_isTotalQtyReached) {
          _addRow();
        }

        // Only show No Good alert if the current group has a No Good scan
        if (scanData['result'] == 'No Good') {
          _showNoGoodAlert();
        }

        // Save current state after successful group save
        await _saveCurrentState();
      } catch (e) {
        print('Error saving scan group: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving scan group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      print('\n=== Group Not Complete Yet ===');
      print('Pending scans: ${_pendingScans.length}');
      print('Required scans per group: $codeCount');

      // Show No Good alert immediately if this scan is No Good
      if (result == 'No Good') {
        _showNoGoodAlert();
      }

      if (!_isTotalQtyReached) {
        _addRow();
      }
    }
  }

  /// Displays an alert dialog when a "No Good" result is recorded.
  void _showNoGoodAlert() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
                    print(
                        "Emergency button pressed - checking if it's a valid mouse click");
                    // Only handle direct mouse clicks, ignore keyboard events
                    if (RendererBinding
                        .instance.mouseTracker.mouseIsConnected) {
                      print(
                          "Mouse is connected - proceeding with emergency stop");
                      // Add a small delay to prevent accidental triggers
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (mounted) {
                          // Calculate progress info
                          final int currentQty =
                              int.tryParse(qtyPerBoxController.text) ?? 0;
                          final int targetQty = int.tryParse(
                                  widget.scanData?['qtyPerBox'] ?? '0') ??
                              0;
                          final bool isIncomplete = currentQty < targetQty;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => EmergencyStop(
                              itemName: itemName,
                              lotNumber: lotNumber,
                              content: _labelContent ?? content,
                              poNo: poNo,
                              quantity: totalQtyController.text,
                              tableData: _tableData
                                  .where((item) =>
                                      item['content']?.isNotEmpty == true)
                                  .map(
                                      (item) => Map<String, dynamic>.from(item))
                                  .toList(),
                              username: 'operator',
                              isIncomplete: isIncomplete,
                              targetQty: targetQty,
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
                    /* Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Back'),
                      ),
                    ), */
                    const Text(
                      'Scan Item',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
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
                          child: Text(
                            goodCountController.text,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                        const Text(
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
                          child: Text(
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
                            _updateGroupCounts();
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

      for (var data
          in _tableData.where((item) => item['result']?.isNotEmpty == true)) {
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
        sessionData.sort(
            (a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

        // Get the codes in group for this session
        int codesInGroup = sessionData.first['codesInGroup'] ?? 1;

        // Count complete groups in this session
        int completeGroups = sessionData.length ~/ codesInGroup;
        totalGroups += completeGroups;
      });

      return totalGroups;
    } else {
      // For counting items, count individual good scans
      return _tableData.where((item) => item['result'] == 'Good').length;
    }
  }

  // Add new method to save current state
  Future<void> _saveCurrentState() async {
    try {
      print('\n=== Saving Current State ===');
      final currentState = {
        'itemName': itemName,
        'poNo': poNo,
        'lotNumber': lotNumber,
        'content': content,
        'operatorScanId': operatorScanId,
        'totalQty': totalQty,
        'qtyPerBox': qtyPerBoxController.text,
        'inspectionQty': inspectionQtyController.text,
        'goodCount': goodCountController.text,
        'noGoodCount': noGoodCountController.text,
        'tableData': _tableData,
        'sessionId': _sessionId,
        'isQtyPerBoxReached': _isQtyPerBoxReached,
        'isTotalQtyReached': _isTotalQtyReached,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await DatabaseHelper().saveCurrentState(currentState);
      print('Current state saved successfully');
    } catch (e) {
      print('Error saving current state: $e');
    }
  }

  // Add method to restore previous state
  Future<void> _restorePreviousState() async {
    try {
      print('\n=== Restoring Previous State ===');
      final previousState = await DatabaseHelper().getLastSavedState(itemName);

      if (previousState != null && previousState['timestamp'] != null) {
        // Check if the state is from the last 24 hours
        final savedTime = DateTime.parse(previousState['timestamp']);
        final now = DateTime.now();
        if (now.difference(savedTime).inHours <= 24) {
          setState(() {
            qtyPerBoxController.text = previousState['qtyPerBox'] ?? '';
            inspectionQtyController.text = previousState['inspectionQty'] ?? '';
            goodCountController.text = previousState['goodCount'] ?? '';
            noGoodCountController.text = previousState['noGoodCount'] ?? '';
            _isQtyPerBoxReached = previousState['isQtyPerBoxReached'] ?? false;
            _isTotalQtyReached = previousState['isTotalQtyReached'] ?? false;

            // Restore table data
            _tableData.clear();
            final savedTableData = previousState['tableData'] as List;
            _tableData.addAll(
                savedTableData.map((item) => Map<String, dynamic>.from(item)));

            print('Previous state restored successfully');
          });
        } else {
          print('Saved state is older than 24 hours - starting fresh');
        }
      }
    } catch (e) {
      print('Error restoring previous state: $e');
    }
  }

  // Add periodic state saving
  Timer? _autoSaveTimer;
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
