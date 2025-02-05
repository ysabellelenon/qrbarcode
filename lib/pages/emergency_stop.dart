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

  const EmergencyStop({
    Key? key,
    required this.itemName,
    required this.lotNumber,
    required this.content,
    required this.poNo,
    required this.quantity,
    required this.tableData,
    required this.username,
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

  @override
  void initState() {
    super.initState();
    _loadScannedData();
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
              onSubmitted: (_) {
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
                onPressed: () {
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
    print('EmergencyStop - Showing summary with:');
    print('itemName: ${widget.itemName}');
    print('lotNumber: ${widget.lotNumber}');
    print('content: ${widget.content}');
    print('poNo: ${widget.poNo}');
    print('quantity: ${widget.quantity}');

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
          onPrint: _printSummary,
        ),
      ),
    );
  }

  void _printSummary() async {
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
            onSubmitted: (_) {
              _validatePassword();
            },
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
    required this.onPrint,
  }) : super(key: key);

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
  }

  String get _combinedContent => '${content}_$lotNumber';

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
            _buildInfoSection('Content', _combinedContent),
            _buildInfoSection('P.O Number', poNo),
            _buildInfoSection('Quantity', quantity),
            _buildInfoSection('Remarks', remarks),
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
                title: '', // Empty title since we already have one above
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      onPrint();
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      onPrint();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
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
}
