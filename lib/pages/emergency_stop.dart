import 'package:flutter/material.dart';
import 'package:qrbarcode/constants.dart';
import '../database_helper.dart';
import '../widgets/previous_scans_table.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../utils/pdf_generator.dart';

class EmergencyStop extends StatefulWidget {
  final String itemName;
  final String lotNumber;
  final String content;
  final String poNo;
  final String quantity;
  final List<Map<String, dynamic>> tableData;
  final String username;
  final bool isIncomplete;
  final int targetQty;

  const EmergencyStop({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
    required this.username,
    this.isIncomplete = false,
    this.targetQty = 0,
  }) : super(key: key);

  @override
  _EmergencyStopState createState() => _EmergencyStopState();
}

class _EmergencyStopState extends State<EmergencyStop> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  String _errorMessage = '';
  List<Map<String, dynamic>> _scannedData = [];
  bool _isLoading = true;
  Map<String, int> _counts = {
    'inspectionQty': 0,
    'goodCount': 0,
    'noGoodCount': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadScannedData();
    _loadCounts();
  }

  Future<void> _loadScannedData() async {
    try {
      final scans =
          await DatabaseHelper().getAllHistoricalScans(widget.itemName);
      setState(() {
        _scannedData = scans;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading scanned data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCounts() async {
    try {
      print('\n=== Loading Emergency Stop Counts ===');
      print('Item Name: ${widget.itemName}');

      // Get codes per group from item configuration
      final items = await DatabaseHelper().getItems();
      final matchingItem = items.firstWhere(
        (item) => item['itemCode'] == widget.itemName,
        orElse: () => {},
      );
      int codesPerGroup = int.parse(matchingItem['codeCount'] ?? '1');
      print('Codes per group from configuration: $codesPerGroup');

      // Group the scans by session and group number
      Map<String, Map<int, List<Map<String, dynamic>>>> groupedScans = {};
      print('\nProcessing scans for grouping:');
      print('Total scans to process: ${_scannedData.length}');

      // Process all scans
      for (var scan
          in _scannedData.where((item) => item['result']?.isNotEmpty == true)) {
        String sessionId = scan['sessionId']?.toString() ?? '';
        int groupNum = scan['groupNumber'] ?? 1;

        print('\nProcessing scan:');
        print('Session ID: $sessionId');
        print('Group Number: $groupNum');
        print('Content: ${scan['content']}');
        print('Result: ${scan['result']}');

        groupedScans[sessionId] = groupedScans[sessionId] ?? {};
        groupedScans[sessionId]![groupNum] =
            groupedScans[sessionId]![groupNum] ?? [];
        groupedScans[sessionId]![groupNum]!.add(scan);
      }

      int totalGoodGroups = 0;
      int totalNoGoodGroups = 0;
      int totalCompletedGroups = 0;

      print('\nCounting completed groups:');
      // Count completed groups
      groupedScans.forEach((sessionId, groups) {
        print('\nSession: $sessionId');
        groups.forEach((groupNum, scans) {
          print('Group $groupNum - Scans count: ${scans.length}');
          if (scans.length == codesPerGroup) {
            totalCompletedGroups++;
            bool isGroupGood = scans.every((scan) => scan['result'] == 'Good');
            print('Group $groupNum is complete:');
            print('- All scans good? $isGroupGood');
            print('- Scan results: ${scans.map((s) => s['result']).toList()}');

            if (isGroupGood) {
              totalGoodGroups++;
              print('- Counted as Good Group');
            } else {
              totalNoGoodGroups++;
              print(
                  '- Counted as No Good Group (contains at least one No Good)');
            }
          } else {
            print(
                'Group $groupNum is incomplete (${scans.length}/$codesPerGroup scans)');
          }
        });
      });

      print('\nFinal Counts:');
      print('Total Completed Groups: $totalCompletedGroups');
      print('Total Good Groups: $totalGoodGroups');
      print('Total No Good Groups: $totalNoGoodGroups');

      setState(() {
        _counts = {
          'goodCount': totalGoodGroups,
          'noGoodCount': totalNoGoodGroups,
          'inspectionQty': totalCompletedGroups,
        };
      });
      print('State updated with new counts');
    } catch (e) {
      print('Error in _loadCounts: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  void _validatePassword() async {
    final user = await DatabaseHelper().getUserByUsernameAndPassword(
      widget.username,
      _passwordController.text,
    );

    if (user != null) {
      _showRemarksDialog();
    } else {
      setState(() {
        _errorMessage = 'Invalid password';
      });
    }
  }

  void _showRemarksDialog() {
    String? errorText;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Remarks'),
            shape: RoundedRectangleBorder(
              borderRadius: kBorderRadiusSmallAll,
            ),
            content: TextField(
              controller: _remarksController,
              decoration: InputDecoration(
                hintText: 'Enter reason for temporary stoppage',
                border: const OutlineInputBorder(),
                errorText: errorText,
              ),
              maxLines: 3,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                if (_remarksController.text.trim().isEmpty) {
                  setState(() {
                    errorText = 'Please enter remarks';
                  });
                  return;
                }
                Navigator.pop(context);
                _showSummaryPage();
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                focusNode: FocusNode(),
                onPressed: () async {
                  if (_remarksController.text.trim().isEmpty) {
                    setState(() {
                      errorText = 'Please enter remarks';
                    });
                    return;
                  }
                  Navigator.pop(context);
                  _showSummaryPage();
                },
                child: const Text('Done'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showSummaryPage() {
    print(
        'emergency_stop > _showSummaryPage > EmergencyStop - Showing summary with:');
    print('emergency_stop > _showSummaryPage > itemName: ${widget.itemName}');
    print('emergency_stop > _showSummaryPage > lotNumber: ${widget.lotNumber}');
    print('emergency_stop > _showSummaryPage > content: ${widget.content}');
    print('emergency_stop > _showSummaryPage > poNo: ${widget.poNo}');
    print('emergency_stop > _showSummaryPage > quantity: ${widget.quantity}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmergencySummary(
          itemName: widget.itemName,
          lotNumber: widget.lotNumber,
          date: DateTime.now(),
          content: widget.content,
          poNo: widget.poNo,
          quantity: widget.quantity,
          tableData: _scannedData,
          remarks: _remarksController.text,
          counts: _counts,
          onPrint: () {
            _printSummary().then((_) async {
              // Clear data only after showing summary and printing
              try {
                await DatabaseHelper().clearAllDataForItem(widget.itemName);
                print(
                    'Successfully cleared all data for item: ${widget.itemName}');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'All data has been cleared. Starting fresh on next scan.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                print('Error clearing data: $e');
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _printSummary() async {
    try {
      await generateAndSavePdf(
        itemName: widget.itemName,
        lotNumber: widget.lotNumber,
        content: widget.content,
        poNo: widget.poNo,
        quantity: widget.quantity,
        tableData: _scannedData,
        remarks: _remarksController.text,
        isEmergencyStop: true,
        onSuccess: (String outputFile) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Success'),
                  shape: RoundedRectangleBorder(
                    borderRadius: kBorderRadiusSmallAll,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PDF saved successfully to:'),
                      const SizedBox(height: 8),
                      SelectableText(outputFile),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          if (Platform.isMacOS) {
                            await Process.run('open', [outputFile]);
                          } else if (Platform.isWindows) {
                            await Process.run(
                                'cmd', ['/c', 'start', '', outputFile]);
                          }
                        } catch (e) {
                          print('Error opening file: $e');
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Error'),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: kBorderRadiusSmallAll,
                                  ),
                                  content: Text('Failed to open file: $e'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                          }
                        }
                      },
                      child: const Text('Open File'),
                    ),
                  ],
                );
              },
            );
          }
        },
        onError: (String error) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text('Failed to generate PDF: $error'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                );
              },
            );
          }
        },
      );
    } catch (e) {
      print('Error in _printSummary: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to generate PDF: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emergency Stop'),
      shape: RoundedRectangleBorder(
        borderRadius: kBorderRadiusSmallAll,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter password to confirm'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            enableInteractiveSelection: true,
            onSubmitted: (_) => _validatePassword(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validatePassword,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class EmergencySummary extends StatelessWidget {
  final String itemName;
  final String lotNumber;
  final DateTime date;
  final String content;
  final String poNo;
  final String quantity;
  final List<Map<String, dynamic>> tableData;
  final String remarks;
  final Map<String, int> counts;
  final VoidCallback onPrint;

  const EmergencySummary({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.date,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
    required this.remarks,
    required this.counts,
    required this.onPrint,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Stop Summary'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection('Item Name', itemName),
            _buildInfoSection('Lot Number', lotNumber),
            _buildInfoSection('Date', _formatDate(date)),
            _buildInfoSection('Content', content),
            _buildInfoSection('P.O Number', poNo),
            _buildInfoSection('Total QTY', quantity),
            _buildInfoSection('Remarks', remarks),

            // Add counts section
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Counts Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCountRow(
                      'Inspection QTY', counts['inspectionQty'] ?? 0),
                  _buildCountRow('Good Count', counts['goodCount'] ?? 0,
                      color: Colors.green),
                  _buildCountRow('No Good Count', counts['noGoodCount'] ?? 0,
                      color: Colors.red),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'Results Table',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: PreviousScansTable(
                itemName: itemName,
                title: '',
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: onPrint,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SelectableText(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
